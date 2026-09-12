/**
 * OrderRestController
 *
 * Apex REST resource for Order__c operations. Thin controller that delegates
 * all business logic to OrderService. Integrates with Postman as described
 * in project requirement Section 8.
 *
 * Base URL: /services/apexrest/orders/
 *
 * Supported operations:
 *
 *   POST /services/apexrest/orders/
 *       Creates a new Order__c with Order_Item__c children. Returns the new
 *       order Id together with subtotal, delivery charge, and grand total.
 *
 *   PUT /services/apexrest/orders/{orderId}
 *       Updates the Status__c of an existing Order__c. The existing
 *       Order_Invalid_Status_Transition validation rule enforces the lifecycle.
 *
 *   GET /services/apexrest/orders/{orderId}
 *       Returns the full order with its items and delivery record. Useful for
 *       confirming state after a POST or PUT.
 *
 * Security:
 *   - without sharing: integration-facing REST resource. All SOQL uses
 *     WITH USER_MODE to enforce field-level security.
 *   - All user-supplied Id values are validated before use in SOQL.
 *   - Request bodies are deserialized using typed inner classes to prevent
 *     JSON injection.
 *
 * Satisfies project requirements:
 *   Section 8 "POST - Create an order" and "PUT - Update order status".
 */
@RestResource(urlMapping='/orders/*')
global without sharing class OrderRestController {

    // -----------------------------------------------------------------------
    // Request / response DTOs
    // -----------------------------------------------------------------------

    /** Request body for POST /orders/. */
    global class CreateOrderRequest {
        /** Salesforce Id of the customer Contact record. Required. */
        global String customerId;
        /** One or more order line items. Required. */
        global List<ItemInput> items;
    }

    /** Single line item within a CreateOrderRequest. */
    global class ItemInput {
        /** Display name of the food item ordered. Required. */
        global String  productName;
        /** Number of units. Required; must be >= 1. */
        global Integer quantity;
        /** Unit price. Required; must be >= 0. */
        global Decimal price;
    }

    /** Request body for PUT /orders/{id}. */
    global class UpdateStatusRequest {
        /** New status value (e.g. Accepted, Preparing, Out for Delivery, Delivered, Cancelled). Required. */
        global String status;
    }

    /** Unified API response envelope for all operations. */
    global class ApiResponse {
        global Boolean success;
        global String  message;
        global String  orderId;
        global String  orderName;
        global String  status;
        global Decimal subtotal;
        global Decimal deliveryCharge;
        global Decimal grandTotal;
        global List<OrderItemDto> items;
        global DeliveryDto delivery;
    }

    /** Serialisable representation of an Order_Item__c record. */
    global class OrderItemDto {
        global String  id;
        global String  productName;
        global Integer quantity;
        global Decimal price;
        global Decimal lineTotal;
    }

    /** Serialisable representation of a Delivery__c record. */
    global class DeliveryDto {
        global String id;
        global String status;
        global String deliveryPartnerId;
        global String deliveryDate;
    }

    // -----------------------------------------------------------------------
    // HTTP handlers
    // -----------------------------------------------------------------------

    /**
     * Creates a new Order__c with its Order_Item__c children.
     * Delegates to OrderService.createOrder().
     *
     * Expected JSON body:
     * {
     *   "customerId": "003xx...",
     *   "items": [
     *     { "productName": "Margherita Pizza", "quantity": 2, "price": 12.99 }
     *   ]
     * }
     *
     * @return ApiResponse with orderId, subtotal, deliveryCharge, grandTotal.
     */
    @HttpPost
    global static ApiResponse createOrder() {
        RestRequest  req  = RestContext.request;
        RestResponse resp = RestContext.response;
        ApiResponse  response = new ApiResponse();

        try {
            if (req.requestBody == null || String.isBlank(req.requestBody.toString())) {
                resp.statusCode   = 400;
                response.success  = false;
                response.message  = 'Request body is required.';
                return response;
            }

            CreateOrderRequest body = (CreateOrderRequest) JSON.deserialize(
                req.requestBody.toString(),
                CreateOrderRequest.class
            );

            // Map REST request DTO → service request DTO.
            OrderService.CreateOrderRequest serviceReq = new OrderService.CreateOrderRequest();
            serviceReq.customerId = (Id) body.customerId;
            serviceReq.items      = toServiceItems(body.items);

            OrderService.CreateOrderResult result = OrderService.createOrder(serviceReq);

            resp.statusCode        = 201;
            response.success       = true;
            response.message       = 'Order created successfully.';
            response.orderId       = result.orderId;
            response.status        = result.status;
            response.subtotal      = result.subtotal;
            response.deliveryCharge = result.deliveryCharge;
            response.grandTotal    = result.grandTotal;

        } catch (OrderService.OrderServiceException serviceEx) {
            resp.statusCode  = 400;
            response.success = false;
            response.message = serviceEx.getMessage();
        } catch (JSONException jsonEx) {
            resp.statusCode  = 400;
            response.success = false;
            response.message = 'Invalid JSON request body: ' + jsonEx.getMessage();
        } catch (DmlException dmlEx) {
            resp.statusCode  = 422;
            response.success = false;
            response.message = 'Order could not be saved: ' + dmlEx.getDmlMessage(0);
        } catch (Exception ex) {
            resp.statusCode  = 500;
            response.success = false;
            response.message = 'Unexpected error: ' + ex.getMessage();
        }
        return response;
    }

    /**
     * Updates the Status__c of an existing Order__c.
     * orderId must be provided as a URL path segment.
     *
     * URL example:
     *   PUT /services/apexrest/orders/a00xx000001AbCdAAK
     *
     * Expected JSON body:
     * { "status": "Accepted" }
     *
     * @return ApiResponse indicating success or failure.
     */
    @HttpPut
    global static ApiResponse updateOrderStatus() {
        RestRequest  req  = RestContext.request;
        RestResponse resp = RestContext.response;
        ApiResponse  response = new ApiResponse();

        try {
            String orderId = extractSegmentFromUri(req.requestURI, '/orders/');
            if (String.isBlank(orderId)) {
                resp.statusCode  = 400;
                response.success = false;
                response.message = 'Order Id must be provided in the URL path, e.g. /orders/{orderId}';
                return response;
            }
            if (!isValidSalesforceId(orderId)) {
                resp.statusCode  = 400;
                response.success = false;
                response.message = 'Invalid orderId format. Provide a 15 or 18 character Salesforce Id.';
                return response;
            }
            if (req.requestBody == null || String.isBlank(req.requestBody.toString())) {
                resp.statusCode  = 400;
                response.success = false;
                response.message = 'Request body with "status" field is required.';
                return response;
            }

            UpdateStatusRequest body = (UpdateStatusRequest) JSON.deserialize(
                req.requestBody.toString(),
                UpdateStatusRequest.class
            );
            if (String.isBlank(body?.status)) {
                resp.statusCode  = 400;
                response.success = false;
                response.message = 'The "status" field in the request body is required.';
                return response;
            }

            OrderService.updateOrderStatus((Id) orderId, body.status);

            resp.statusCode  = 200;
            response.success = true;
            response.orderId = orderId;
            response.status  = body.status;
            response.message = 'Order status updated to ' + body.status + '.';

        } catch (OrderService.OrderServiceException serviceEx) {
            resp.statusCode  = 400;
            response.success = false;
            response.message = serviceEx.getMessage();
        } catch (JSONException jsonEx) {
            resp.statusCode  = 400;
            response.success = false;
            response.message = 'Invalid JSON request body: ' + jsonEx.getMessage();
        } catch (DmlException dmlEx) {
            resp.statusCode  = 422;
            response.success = false;
            response.message = 'Status update failed: ' + dmlEx.getDmlMessage(0);
        } catch (Exception ex) {
            resp.statusCode  = 500;
            response.success = false;
            response.message = 'Unexpected error: ' + ex.getMessage();
        }
        return response;
    }

    /**
     * Returns full order details including items and delivery record.
     *
     * URL example:
     *   GET /services/apexrest/orders/a00xx000001AbCdAAK
     *
     * @return ApiResponse containing order data.
     */
    @HttpGet
    global static ApiResponse getOrder() {
        RestRequest  req  = RestContext.request;
        RestResponse resp = RestContext.response;
        ApiResponse  response = new ApiResponse();

        try {
            String orderId = extractSegmentFromUri(req.requestURI, '/orders/');
            if (String.isBlank(orderId)) {
                resp.statusCode  = 400;
                response.success = false;
                response.message = 'Order Id must be provided in the URL path, e.g. /orders/{orderId}';
                return response;
            }
            if (!isValidSalesforceId(orderId)) {
                resp.statusCode  = 400;
                response.success = false;
                response.message = 'Invalid orderId format.';
                return response;
            }

            Order__c order = OrderService.getOrderWithDetails((Id) orderId);
            if (order == null) {
                resp.statusCode  = 404;
                response.success = false;
                response.message = 'Order not found for Id: ' + orderId;
                return response;
            }

            Decimal subtotal = order.Total_Amount__c != null ? order.Total_Amount__c : 0;
            Decimal deliveryCharge = DeliveryChargeCalculator.calculate(subtotal);

            resp.statusCode        = 200;
            response.success       = true;
            response.orderId       = order.Id;
            response.orderName     = order.Name;
            response.status        = order.Status__c;
            response.subtotal      = subtotal;
            response.deliveryCharge = deliveryCharge;
            response.grandTotal    = subtotal + deliveryCharge;
            response.items         = toOrderItemDtos(order.Order_Items__r);
            response.delivery      = toDeliveryDto(order.Deliveries__r);

        } catch (OrderService.OrderServiceException serviceEx) {
            resp.statusCode  = 400;
            response.success = false;
            response.message = serviceEx.getMessage();
        } catch (Exception ex) {
            resp.statusCode  = 500;
            response.success = false;
            response.message = 'Unexpected error: ' + ex.getMessage();
        }
        return response;
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /**
     * Maps REST controller ItemInput list to service layer OrderItemInput list.
     * No SOQL or DML.
     */
    private static List<OrderService.OrderItemInput> toServiceItems(
        List<ItemInput> inputs
    ) {
        List<OrderService.OrderItemInput> serviceItems =
            new List<OrderService.OrderItemInput>();
        if (inputs == null) {
            return serviceItems;
        }
        for (ItemInput input : inputs) {
            OrderService.OrderItemInput si = new OrderService.OrderItemInput();
            si.productName = input.productName;
            si.quantity    = input.quantity;
            si.price       = input.price;
            serviceItems.add(si);
        }
        return serviceItems;
    }

    /**
     * Converts Order_Item__c child records to OrderItemDto objects.
     */
    private static List<OrderItemDto> toOrderItemDtos(
        List<Order_Item__c> orderItems
    ) {
        List<OrderItemDto> dtos = new List<OrderItemDto>();
        if (orderItems == null) {
            return dtos;
        }
        for (Order_Item__c item : orderItems) {
            OrderItemDto dto  = new OrderItemDto();
            dto.id            = item.Id;
            dto.productName   = item.Product_Name__c;
            dto.quantity      = (Integer) item.Quantity__c;
            dto.price         = item.Price__c;
            dto.lineTotal     = item.Line_Total__c;
            dtos.add(dto);
        }
        return dtos;
    }

    /**
     * Returns the first Delivery__c from the child list as a DeliveryDto,
     * or null if no delivery exists yet.
     */
    private static DeliveryDto toDeliveryDto(List<Delivery__c> deliveries) {
        if (deliveries == null || deliveries.isEmpty()) {
            return null;
        }
        Delivery__c d     = deliveries[0];
        DeliveryDto dto   = new DeliveryDto();
        dto.id            = d.Id;
        dto.status        = d.Status__c;
        dto.deliveryPartnerId = d.Delivery_Partner__c;
        dto.deliveryDate  = d.Delivery_Date__c != null
            ? String.valueOf(d.Delivery_Date__c)
            : null;
        return dto;
    }

    /**
     * Extracts the path segment after basePath from a request URI.
     * Returns null when no segment is present.
     */
    private static String extractSegmentFromUri(String requestUri, String basePath) {
        if (String.isBlank(requestUri)) {
            return null;
        }
        Integer baseIdx = requestUri.indexOf(basePath);
        if (baseIdx == -1) {
            return null;
        }
        String segment = requestUri.substring(baseIdx + basePath.length());
        Integer queryIdx = segment.indexOf('?');
        if (queryIdx > -1) {
            segment = segment.substring(0, queryIdx);
        }
        segment = segment.trim();
        return String.isBlank(segment) ? null : segment;
    }

    /**
     * Returns true when value is a 15 or 18-character alphanumeric Salesforce Id.
     */
    private static Boolean isValidSalesforceId(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        return Pattern.matches('[a-zA-Z0-9]{15}|[a-zA-Z0-9]{18}', value);
    }
}