/**
 * OrderServiceTest
 *
 * Comprehensive test coverage for OrderService.
 *
 * Scenarios covered:
 *
 * createOrder():
 *  - Successful creation with a single item
 *  - Successful creation with multiple items
 *  - Null request throws OrderServiceException
 *  - Null customerId throws OrderServiceException
 *  - Null items list throws OrderServiceException
 *  - Empty items list throws OrderServiceException
 *  - Blank product name throws OrderServiceException
 *  - Zero quantity throws OrderServiceException
 *  - Negative quantity throws OrderServiceException
 *  - Negative price throws OrderServiceException
 *  - Zero price is accepted (price >= 0 is valid)
 *  - Result contains correct subtotal, delivery charge, and grand total
 *  - Order is created with Status "Pending"
 *
 * updateOrderStatus():
 *  - Successful valid status transition (Pending → Accepted)
 *  - Null orderId throws OrderServiceException
 *  - Blank status throws OrderServiceException
 *  - Invalid status transition throws DmlException (validation rule enforcement)
 *
 * getOrderWithDetails():
 *  - Returns populated Order__c for an existing order
 *  - Returns null for a non-existent order Id
 *  - Null orderId throws OrderServiceException
 *  - Order Items sub-query is populated when items exist
 */
@isTest
private class OrderServiceTest {

    // -----------------------------------------------------------------------
    // Test data setup
    // -----------------------------------------------------------------------

    @TestSetup
    static void makeData() {
        Contact customer = new Contact(
            LastName = 'ServiceTestCustomer',
            Email    = 'service.test@example.com'
        );
        insert customer;
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private static Contact getCustomer() {
        return [SELECT Id FROM Contact WHERE LastName = 'ServiceTestCustomer' LIMIT 1];
    }

    private static OrderService.CreateOrderRequest buildRequest(
        Id customerId,
        List<OrderService.OrderItemInput> items
    ) {
        OrderService.CreateOrderRequest req = new OrderService.CreateOrderRequest();
        req.customerId = customerId;
        req.items      = items;
        return req;
    }

    private static OrderService.OrderItemInput buildItem(
        String name, Integer qty, Decimal price
    ) {
        OrderService.OrderItemInput item = new OrderService.OrderItemInput();
        item.productName = name;
        item.quantity    = qty;
        item.price       = price;
        return item;
    }

    // -----------------------------------------------------------------------
    // createOrder() — success paths
    // -----------------------------------------------------------------------

    @isTest
    static void createOrder_singleItem_succeeds() {
        Contact c = getCustomer();

        OrderService.CreateOrderRequest req = buildRequest(
            c.Id,
            new List<OrderService.OrderItemInput>{
                buildItem('Margherita Pizza', 2, 12.99)
            }
        );

        Test.startTest();
        OrderService.CreateOrderResult result = OrderService.createOrder(req);
        Test.stopTest();

        System.assertNotEquals(null, result,
            'createOrder() must return a non-null result.');
        System.assertNotEquals(null, result.orderId,
            'Result must contain the new Order Id.');
        System.assertEquals('Pending', result.status,
            'Newly created order must have status Pending.');

        // Subtotal = 2 × 12.99 = 25.98
        System.assertEquals(25.98, result.subtotal,
            'Subtotal should be 2 × $12.99 = $25.98.');

        // Delivery charge = 2.50 + (25.98 × 0.05) = 2.50 + 1.299 ≈ 3.80 (HALF_UP)
        Decimal expectedCharge = DeliveryChargeCalculator.calculate(result.subtotal);
        System.assertEquals(expectedCharge, result.deliveryCharge,
            'Delivery charge must match DeliveryChargeCalculator.calculate(subtotal).');

        System.assertEquals(result.subtotal + result.deliveryCharge, result.grandTotal,
            'Grand total must be subtotal + delivery charge.');
    }

    @isTest
    static void createOrder_multipleItems_sumsSubtotalCorrectly() {
        Contact c = getCustomer();

        OrderService.CreateOrderRequest req = buildRequest(
            c.Id,
            new List<OrderService.OrderItemInput>{
                buildItem('Burger',  2, 8.00),   // 16.00
                buildItem('Fries',   1, 3.50),   //  3.50
                buildItem('Soda',    3, 2.00)    //  6.00  → total 25.50
            }
        );

        Test.startTest();
        OrderService.CreateOrderResult result = OrderService.createOrder(req);
        Test.stopTest();

        System.assertEquals(25.50, result.subtotal,
            'Subtotal must be 16.00 + 3.50 + 6.00 = 25.50.');
        System.assertNotEquals(null, result.orderId,
            'Result must contain the new Order Id.');

        // Verify items were persisted.
        List<Order_Item__c> items = [
            SELECT Id FROM Order_Item__c WHERE Order__c = :result.orderId
        ];
        System.assertEquals(3, items.size(),
            'Three Order_Item__c records should have been created.');
    }

    @isTest
    static void createOrder_zeroPriceItem_isAccepted() {
        // price >= 0 is valid per OrderService validation.
        Contact c = getCustomer();

        OrderService.CreateOrderRequest req = buildRequest(
            c.Id,
            new List<OrderService.OrderItemInput>{
                buildItem('Free Sample', 1, 0.00)
            }
        );

        Test.startTest();
        OrderService.CreateOrderResult result = OrderService.createOrder(req);
        Test.stopTest();

        System.assertNotEquals(null, result.orderId,
            'An item with price = 0 should be accepted.');
        System.assertEquals(0, result.subtotal,
            'Subtotal should be $0 for a single free item.');
    }

    @isTest
    static void createOrder_orderIsPersistedInDatabase() {
        Contact c = getCustomer();

        OrderService.CreateOrderRequest req = buildRequest(
            c.Id,
            new List<OrderService.OrderItemInput>{ buildItem('Wrap', 1, 9.99) }
        );

        Test.startTest();
        OrderService.CreateOrderResult result = OrderService.createOrder(req);
        Test.stopTest();

        List<Order__c> orders = [
            SELECT Id, Customer__c, Status__c, Total_Amount__c
            FROM   Order__c
            WHERE  Id = :result.orderId
        ];
        System.assertEquals(1, orders.size(), 'One Order__c record should exist.');
        System.assertEquals(c.Id, orders[0].Customer__c,
            'Order should be linked to the correct customer Contact.');
        System.assertEquals('Pending', orders[0].Status__c,
            'Order status should be Pending.');
        System.assertEquals(9.99, orders[0].Total_Amount__c,
            'Total_Amount__c should reflect the single item price ($9.99).');
    }

    // -----------------------------------------------------------------------
    // createOrder() — validation failures
    // -----------------------------------------------------------------------

    @isTest
    static void createOrder_nullRequest_throwsException() {
        Test.startTest();
        try {
            OrderService.createOrder(null);
            System.assert(false, 'Expected OrderServiceException was not thrown.');
        } catch (OrderService.OrderServiceException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('null'),
                'Exception message should reference the null request. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void createOrder_nullCustomerId_throwsException() {
        OrderService.CreateOrderRequest req = buildRequest(
            null,
            new List<OrderService.OrderItemInput>{ buildItem('Pizza', 1, 10.00) }
        );

        Test.startTest();
        try {
            OrderService.createOrder(req);
            System.assert(false, 'Expected OrderServiceException was not thrown.');
        } catch (OrderService.OrderServiceException e) {
            System.assert(
                e.getMessage().toLowerCase().contains('customer'),
                'Exception message should mention customer ID. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void createOrder_nullItemsList_throwsException() {
        Contact c = getCustomer();
        OrderService.CreateOrderRequest req = buildRequest(c.Id, null);

        Test.startTest();
        try {
            OrderService.createOrder(req);
            System.assert(false, 'Expected OrderServiceException was not thrown.');
        } catch (OrderService.OrderServiceException e) {
            System.assert(
                e.getMessage().toLowerCase().contains('item'),
                'Exception message should mention items. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void createOrder_emptyItemsList_throwsException() {
        Contact c = getCustomer();
        OrderService.CreateOrderRequest req = buildRequest(
            c.Id,
            new List<OrderService.OrderItemInput>()
        );

        Test.startTest();
        try {
            OrderService.createOrder(req);
            System.assert(false, 'Expected OrderServiceException was not thrown.');
        } catch (OrderService.OrderServiceException e) {
            System.assert(
                e.getMessage().toLowerCase().contains('item'),
                'Exception message should mention items. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void createOrder_blankProductName_throwsException() {
        Contact c = getCustomer();
        OrderService.CreateOrderRequest req = buildRequest(
            c.Id,
            new List<OrderService.OrderItemInput>{ buildItem('  ', 1, 5.00) }
        );

        Test.startTest();
        try {
            OrderService.createOrder(req);
            System.assert(false, 'Expected OrderServiceException was not thrown.');
        } catch (OrderService.OrderServiceException e) {
            System.assert(
                e.getMessage().toLowerCase().contains('product name'),
                'Exception message should mention product name. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void createOrder_zeroQuantity_throwsException() {
        Contact c = getCustomer();
        OrderService.CreateOrderRequest req = buildRequest(
            c.Id,
            new List<OrderService.OrderItemInput>{ buildItem('Tacos', 0, 5.00) }
        );

        Test.startTest();
        try {
            OrderService.createOrder(req);
            System.assert(false, 'Expected OrderServiceException was not thrown.');
        } catch (OrderService.OrderServiceException e) {
            System.assert(
                e.getMessage().toLowerCase().contains('quantity'),
                'Exception message should mention quantity. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void createOrder_negativeQuantity_throwsException() {
        Contact c = getCustomer();
        OrderService.CreateOrderRequest req = buildRequest(
            c.Id,
            new List<OrderService.OrderItemInput>{ buildItem('Tacos', -1, 5.00) }
        );

        Test.startTest();
        try {
            OrderService.createOrder(req);
            System.assert(false, 'Expected OrderServiceException was not thrown.');
        } catch (OrderService.OrderServiceException e) {
            System.assert(
                e.getMessage().toLowerCase().contains('quantity'),
                'Exception message should mention quantity. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void createOrder_negativePrice_throwsException() {
        Contact c = getCustomer();
        OrderService.CreateOrderRequest req = buildRequest(
            c.Id,
            new List<OrderService.OrderItemInput>{ buildItem('Sushi', 1, -5.00) }
        );

        Test.startTest();
        try {
            OrderService.createOrder(req);
            System.assert(false, 'Expected OrderServiceException was not thrown.');
        } catch (OrderService.OrderServiceException e) {
            System.assert(
                e.getMessage().toLowerCase().contains('price'),
                'Exception message should mention price. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    // -----------------------------------------------------------------------
    // updateOrderStatus() — success paths
    // -----------------------------------------------------------------------

    @isTest
    static void updateOrderStatus_pendingToAccepted_succeeds() {
        Contact c = getCustomer();
        Order__c order = new Order__c(Customer__c = c.Id, Status__c = 'Pending');
        insert order;

        Test.startTest();
        // Pending → Accepted is an allowed transition per the validation rule.
        OrderService.updateOrderStatus(order.Id, 'Accepted');
        Test.stopTest();

        Order__c updated = [SELECT Status__c FROM Order__c WHERE Id = :order.Id];
        System.assertEquals('Accepted', updated.Status__c,
            'Order status should be updated to Accepted.');
    }

    @isTest
    static void updateOrderStatus_pendingToCancelled_succeeds() {
        Contact c = getCustomer();
        Order__c order = new Order__c(Customer__c = c.Id, Status__c = 'Pending');
        insert order;

        Test.startTest();
        OrderService.updateOrderStatus(order.Id, 'Cancelled');
        Test.stopTest();

        Order__c updated = [SELECT Status__c FROM Order__c WHERE Id = :order.Id];
        System.assertEquals('Cancelled', updated.Status__c,
            'Order status should be updated to Cancelled.');
    }

    // -----------------------------------------------------------------------
    // updateOrderStatus() — validation failures
    // -----------------------------------------------------------------------

    @isTest
    static void updateOrderStatus_nullOrderId_throwsException() {
        Test.startTest();
        try {
            OrderService.updateOrderStatus(null, 'Accepted');
            System.assert(false, 'Expected OrderServiceException was not thrown.');
        } catch (OrderService.OrderServiceException e) {
            System.assert(
                e.getMessage().toLowerCase().contains('null') ||
                e.getMessage().toLowerCase().contains('orderid') ||
                e.getMessage().toLowerCase().contains('order id'),
                'Exception message should reference orderId. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void updateOrderStatus_blankStatus_throwsException() {
        Contact c = getCustomer();
        Order__c order = new Order__c(Customer__c = c.Id, Status__c = 'Pending');
        insert order;

        Test.startTest();
        try {
            OrderService.updateOrderStatus(order.Id, '');
            System.assert(false, 'Expected OrderServiceException was not thrown.');
        } catch (OrderService.OrderServiceException e) {
            System.assert(
                e.getMessage().toLowerCase().contains('status') ||
                e.getMessage().toLowerCase().contains('blank'),
                'Exception message should mention status. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void updateOrderStatus_invalidTransition_throwsDmlException() {
        Contact c = getCustomer();
        Order__c order = new Order__c(Customer__c = c.Id, Status__c = 'Pending');
        insert order;

        // Pending → Preparing is NOT an allowed transition.
        // The Order_Invalid_Status_Transition validation rule blocks it.
        Test.startTest();
        try {
            OrderService.updateOrderStatus(order.Id, 'Preparing');
            System.assert(false, 'Expected DmlException for invalid status transition.');
        } catch (System.DmlException e) {
            System.assert(
                e.getDmlMessage(0).toLowerCase().contains('invalid') ||
                e.getDmlMessage(0).toLowerCase().contains('status'),
                'DmlException message should describe the invalid transition. Got: ' + e.getDmlMessage(0)
            );
        }
        Test.stopTest();
    }

    // -----------------------------------------------------------------------
    // getOrderWithDetails() — success paths
    // -----------------------------------------------------------------------

    @isTest
    static void getOrderWithDetails_existingOrder_returnsOrder() {
        Contact c = getCustomer();
        Order__c order = new Order__c(Customer__c = c.Id, Status__c = 'Pending');
        insert order;
        insert new Order_Item__c(
            Order__c        = order.Id,
            Product_Name__c = 'Pasta',
            Quantity__c     = 1,
            Price__c        = 12.00
        );

        Test.startTest();
        Order__c result = OrderService.getOrderWithDetails(order.Id);
        Test.stopTest();

        System.assertNotEquals(null, result,
            'getOrderWithDetails() must return the Order__c for an existing record.');
        System.assertEquals(order.Id, result.Id,
            'Returned Order Id must match the queried Id.');
        System.assertEquals('Pending', result.Status__c,
            'Returned Order status must be Pending.');
        System.assertEquals(1, result.Order_Items__r.size(),
            'Order_Items__r sub-query should return 1 item.');
        System.assertEquals(12.00, result.Order_Items__r[0].Line_Total__c,
            'Sub-query item Line_Total__c should be $12.');
    }

    @isTest
    static void getOrderWithDetails_noItemsSubquery_returnsEmptyList() {
        Contact c = getCustomer();
        Order__c order = new Order__c(Customer__c = c.Id, Status__c = 'Pending');
        insert order;

        Test.startTest();
        Order__c result = OrderService.getOrderWithDetails(order.Id);
        Test.stopTest();

        System.assertNotEquals(null, result,
            'getOrderWithDetails() must return the Order__c even with no items.');
        System.assertEquals(0, result.Order_Items__r.size(),
            'Order_Items__r sub-query should return 0 items for a fresh order.');
    }

    @isTest
    static void getOrderWithDetails_nonExistentOrderId_returnsNull() {
        // Construct a well-formed but non-existent Order__c Id.
        // Use a different object's Id format to avoid accidentally matching a real Order.
        // The safest approach is to insert and delete so we have a genuine non-existent Id.
        Contact c = getCustomer();
        Order__c phantom = new Order__c(Customer__c = c.Id, Status__c = 'Pending');
        insert phantom;
        Id phantomId = phantom.Id;
        delete phantom;

        Test.startTest();
        Order__c result = OrderService.getOrderWithDetails(phantomId);
        Test.stopTest();

        System.assertEquals(null, result,
            'getOrderWithDetails() must return null for a non-existent Order Id.');
    }

    // -----------------------------------------------------------------------
    // getOrderWithDetails() — validation failures
    // -----------------------------------------------------------------------

    @isTest
    static void getOrderWithDetails_nullOrderId_throwsException() {
        Test.startTest();
        try {
            OrderService.getOrderWithDetails(null);
            System.assert(false, 'Expected OrderServiceException was not thrown.');
        } catch (OrderService.OrderServiceException e) {
            System.assert(
                e.getMessage().toLowerCase().contains('null') ||
                e.getMessage().toLowerCase().contains('orderid') ||
                e.getMessage().toLowerCase().contains('order id'),
                'Exception message should reference the null orderId. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    // -----------------------------------------------------------------------
    // End-to-end integration: createOrder → getOrderWithDetails
    // -----------------------------------------------------------------------

    @isTest
    static void createThenRetrieve_roundTrip_isConsistent() {
        Contact c = getCustomer();

        OrderService.CreateOrderRequest req = buildRequest(
            c.Id,
            new List<OrderService.OrderItemInput>{
                buildItem('Cheeseburger', 2, 7.50),   // 15.00
                buildItem('Onion Rings',  1, 4.00)    //  4.00  → 19.00
            }
        );

        Test.startTest();
        OrderService.CreateOrderResult created = OrderService.createOrder(req);
        Order__c retrieved = OrderService.getOrderWithDetails(created.orderId);
        Test.stopTest();

        System.assertNotEquals(null, retrieved,
            'Created order should be retrievable via getOrderWithDetails().');
        System.assertEquals(created.orderId, retrieved.Id,
            'Retrieved Order Id must match the created Order Id.');
        System.assertEquals(19.00, retrieved.Total_Amount__c,
            'Total_Amount__c should reflect the inserted items after trigger recalculation.');
        System.assertEquals(2, retrieved.Order_Items__r.size(),
            'Two Order_Item__c records should be present.');
    }
}