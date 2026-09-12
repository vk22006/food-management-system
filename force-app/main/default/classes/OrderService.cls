/**
 * OrderService
 *
 * Service class encapsulating core Order__c business logic for the Food Order
 * Management System. Handles transactional order creation (Order header +
 * Order Items in a single DML transaction) and order status updates.
 *
 * Designed to be called from:
 *  - OrderRestController (Apex REST / Postman integration)
 *  - Future @InvocableMethod wrappers if needed
 *
 * Existing declarative automation that fires automatically after DML:
 *  - Order_Set_Date_On_Create (Before-Save Flow) - sets Order_Date__c
 *  - Order_Email_Notification (After-Save Flow) - emails customer
 *  - Order_InApp_Notification (After-Save Flow) - in-app notification
 *  - Order_Restaurant_Staff_Notifications (After-Save Flow) - notifies staff
 *  - Order_Create_Delivery_On_Accept (After-Save Flow) - creates Delivery on Accepted
 *  - Order_Status_Update_Processing (After-Save Flow) - syncs Delivery status
 *  - OrderItemTrigger -> OrderTotalCalculator - recalculates Total_Amount__c
 *
 * Bulk safety:
 *  - All SOQL is outside loops.
 *  - All DML is batched.
 *  - Single-record operations delegate to bulk helpers where appropriate.
 *
 * Satisfies project requirement: Section 7
 *  "Custom logic for Order processing" and "Calculate delivery charges".
 */
public with sharing class OrderService {

    // -----------------------------------------------------------------------
    // Custom exception
    // -----------------------------------------------------------------------

    /**
     * Thrown when Order creation or status-update business rules are violated.
     */
    public class OrderServiceException extends Exception {}

    // -----------------------------------------------------------------------
    // Inner request / response types
    // -----------------------------------------------------------------------

    /**
     * Represents a single line item when creating an order through the service.
     */
    public class OrderItemInput {
        /** Display name of the food item. Required. */
        public String  productName;
        /** Number of units ordered. Must be >= 1. */
        public Integer quantity;
        /** Unit price. Must be >= 0. */
        public Decimal price;
    }

    /**
     * Input parameter for createOrder().
     */
    public class CreateOrderRequest {
        /** Id of the Contact representing the customer. Required. */
        public Id customerId;
        /** One or more items to add to the order. Required; must be non-empty. */
        public List<OrderItemInput> items;
    }

    /**
     * Result returned by createOrder() with pricing breakdown.
     */
    public class CreateOrderResult {
        /** Id of the newly created Order__c record. */
        public Id      orderId;
        /** Sum of all Order_Item__c.Line_Total__c values. */
        public Decimal subtotal;
        /** Delivery charge computed by DeliveryChargeCalculator. */
        public Decimal deliveryCharge;
        /** subtotal + deliveryCharge. */
        public Decimal grandTotal;
        /** Status of the newly created order (always "Pending"). */
        public String  status;
    }

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /**
     * Creates an Order__c header and its child Order_Item__c records in a
     * single Apex transaction. After the inserts, the OrderItemTrigger fires
     * and OrderTotalCalculator updates Total_Amount__c automatically. The
     * delivery charge is computed via DeliveryChargeCalculator and returned
     * in the result.
     *
     * Existing before-save flows (Order_Set_Date_On_Create) and after-save
     * flows (notifications, etc.) fire automatically on the DML - this method
     * does not duplicate any declarative automation.
     *
     * @param request  Order creation request containing customer Id and items.
     * @return         CreateOrderResult with Id, subtotal, delivery charge, and grand total.
     * @throws OrderServiceException if the request is null, has no customer, or has no items.
     * @throws DmlException          if the DML fails (e.g. required field missing).
     *
     * @example
     * OrderService.CreateOrderRequest req = new OrderService.CreateOrderRequest();
     * req.customerId = someContactId;
     * req.items = new List<OrderService.OrderItemInput>();
     * OrderService.OrderItemInput item = new OrderService.OrderItemInput();
     * item.productName = 'Margherita Pizza';
     * item.quantity = 2;
     * item.price = 12.99;
     * req.items.add(item);
     * OrderService.CreateOrderResult result = OrderService.createOrder(req);
     */
    public static CreateOrderResult createOrder(CreateOrderRequest request) {
        validateCreateOrderRequest(request);

        // Insert the Order header.
        // Order_Date__c is set by the Before-Save Flow: Order_Set_Date_On_Create.
        Order__c order = new Order__c(
            Customer__c = request.customerId,
            Status__c   = 'Pending'
        );
        insert order;

        // Build and insert Order Items in a single DML call.
        List<Order_Item__c> orderItems = buildOrderItems(order.Id, request.items);
        if (!orderItems.isEmpty()) {
            insert orderItems;
            // OrderItemTrigger fires here --> OrderTotalCalculator.recalculate()
            // updates Order__c.Total_Amount__c automatically.
        }

        // Re-query the order to read the Total_Amount__c updated by the trigger.
        // One targeted SOQL; not inside a loop.
        Order__c savedOrder = [
            SELECT Id, Total_Amount__c, Status__c
            FROM   Order__c
            WHERE  Id = :order.Id
            WITH USER_MODE
            LIMIT  1
        ];

        Decimal subtotal = savedOrder.Total_Amount__c != null
            ? savedOrder.Total_Amount__c
            : 0;
        Decimal deliveryCharge = DeliveryChargeCalculator.calculate(subtotal);

        CreateOrderResult result = new CreateOrderResult();
        result.orderId        = savedOrder.Id;
        result.subtotal       = subtotal;
        result.deliveryCharge = deliveryCharge;
        result.grandTotal     = subtotal + deliveryCharge;
        result.status         = savedOrder.Status__c;
        return result;
    }

    /**
     * Updates the Status__c of an existing Order__c. The existing validation
     * rule (Order_Invalid_Status_Transition) enforces the lifecycle; if the
     * transition is invalid, a DmlException is thrown by the platform and
     * propagated to the caller.
     *
     * Downstream declarative automation fires automatically on the DML update:
     *  - Order_Status_Update_Processing: syncs related Delivery status
     *  - Order_Create_Delivery_On_Accept: creates Delivery on first Accepted
     *  - Order_Email_Notification: emails the customer
     *  - Order_InApp_Notification: in-app notification to customer
     *  - Order_Restaurant_Staff_Notifications: notifies restaurant staff
     *
     * @param orderId   Id of the Order__c record to update. Must not be null.
     * @param newStatus New status string (must be a valid picklist value).
     * @throws OrderServiceException if orderId or newStatus is blank/null.
     * @throws DmlException          if the validation rule blocks the transition.
     *
     * @example
     * OrderService.updateOrderStatus(anOrderId, 'Accepted');
     */
    public static void updateOrderStatus(Id orderId, String newStatus) {
        if (orderId == null) {
            throw new OrderServiceException('orderId must not be null.');
        }
        if (String.isBlank(newStatus)) {
            throw new OrderServiceException('newStatus must not be blank.');
        }
        // The Order_Invalid_Status_Transition validation rule enforces the
        // lifecycle at the platform level. If the transition is invalid the
        // DmlException will propagate naturally to the caller.
        update new Order__c(Id = orderId, Status__c = newStatus);
    }

    /**
     * Returns a single Order__c with its child Order_Item__c records and any
     * related Delivery__c for use in REST responses.
     *
     * @param orderId  Id of the Order__c record to retrieve.
     * @return         The Order__c with related records, or null if not found.
     * @throws OrderServiceException if orderId is null.
     *
     * @example
     * Order__c order = OrderService.getOrderWithDetails(someOrderId);
     */
    public static Order__c getOrderWithDetails(Id orderId) {
        if (orderId == null) {
            throw new OrderServiceException('orderId must not be null.');
        }
        List<Order__c> orders = [
            SELECT Id, Name, Status__c, Total_Amount__c, Order_Date__c, Customer__c,
                   (SELECT Id, Product_Name__c, Quantity__c, Price__c, Line_Total__c
                    FROM   Order_Items__r
                    ORDER BY CreatedDate),
                   (SELECT Id, Status__c, Delivery_Partner__c, Delivery_Date__c
                    FROM   Deliveries__r
                    LIMIT  1)
            FROM   Order__c
            WHERE  Id = :orderId
            WITH USER_MODE
            LIMIT  1
        ];
        return orders.isEmpty() ? null : orders[0];
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /**
     * Validates the CreateOrderRequest before any DML. Throws
     * OrderServiceException for any invalid state.
     */
    private static void validateCreateOrderRequest(CreateOrderRequest request) {
        if (request == null) {
            throw new OrderServiceException('Order request must not be null.');
        }
        if (request.customerId == null) {
            throw new OrderServiceException('Customer ID is required to create an order.');
        }
        if (request.items == null || request.items.isEmpty()) {
            throw new OrderServiceException('Order must contain at least one item.');
        }
        for (OrderItemInput item : request.items) {
            if (String.isBlank(item?.productName)) {
                throw new OrderServiceException(
                    'Each order item must have a product name.');
            }
            if (item.quantity == null || item.quantity <= 0) {
                throw new OrderServiceException(
                    'Each order item must have a positive quantity.');
            }
            if (item.price == null || item.price < 0) {
                throw new OrderServiceException(
                    'Each order item must have a non-negative price.');
            }
        }
    }

    /**
     * Converts a list of OrderItemInput DTOs into Order_Item__c sObjects
     * ready for insert. All items are assigned the provided orderId as parent.
     * No SOQL or DML inside this helper.
     */
    private static List<Order_Item__c> buildOrderItems(
        Id orderId,
        List<OrderItemInput> inputs
    ) {
        List<Order_Item__c> items = new List<Order_Item__c>();
        for (OrderItemInput input : inputs) {
            items.add(new Order_Item__c(
                Order__c        = orderId,
                Product_Name__c = input.productName,
                Quantity__c     = input.quantity,
                Price__c        = input.price
            ));
        }
        return items;
    }
}