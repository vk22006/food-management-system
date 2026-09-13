/**
 * OrderRestControllerTest
 *
 * Comprehensive test coverage for OrderRestController.
 *
 * Scenarios covered:
 *
 * POST /orders/ (createOrder):
 *  - Valid request body creates order and returns HTTP 201 with success=true
 *  - Valid multi-item order returns correct subtotal, delivery charge, grand total
 *  - Null / empty request body returns HTTP 400
 *  - Malformed (invalid) JSON returns HTTP 400
 *  - Missing customerId in body fails validation and returns HTTP 400
 *  - Empty items list fails validation and returns HTTP 400
 *
 * PUT /orders/{orderId} (updateOrderStatus):
 *  - Valid status update returns HTTP 200 with success=true
 *  - Missing orderId in URL returns HTTP 400
 *  - Invalid orderId format in URL returns HTTP 400
 *  - Null / empty request body returns HTTP 400
 *  - Missing status field in body returns HTTP 400
 *
 * GET /orders/{orderId} (getOrder):
 *  - Valid orderId returns HTTP 200 with order details
 *  - Missing orderId in URL returns HTTP 400
 *  - Invalid orderId format in URL returns HTTP 400
 *  - Non-existent orderId returns HTTP 404
 */
@isTest
private class OrderRestControllerTest {

    // -----------------------------------------------------------------------
    // Test data setup
    // -----------------------------------------------------------------------

    @TestSetup
    static void makeData() {
        Contact customer = new Contact(
            LastName = 'OrderCtrlTestCustomer',
            Email    = 'order.ctrl@example.com'
        );
        insert customer;
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private static Contact getCustomer() {
        return [SELECT Id FROM Contact WHERE LastName = 'OrderCtrlTestCustomer' LIMIT 1];
    }

    private static void setupContext(String httpMethod, String uri, String bodyJson) {
        RestRequest req = new RestRequest();
        req.requestURI  = uri;
        req.httpMethod  = httpMethod;
        if (bodyJson != null) {
            req.requestBody = Blob.valueOf(bodyJson);
        }
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    /** Builds a valid JSON body for a CreateOrderRequest. */
    private static String buildCreateBody(String customerId, String itemsJson) {
        return '{"customerId":"' + customerId + '","items":' + itemsJson + '}';
    }

    private static String singleItemJson() {
        return '[{"productName":"Chicken Wrap","quantity":2,"price":9.50}]';
    }

    private static String multiItemJson() {
        return '[{"productName":"Burger","quantity":1,"price":8.00},'
             + '{"productName":"Fries","quantity":2,"price":3.00}]';
    }

    /**
     * Creates an order through the REST endpoint and returns the orderId string.
     * Used as a setup step for PUT and GET tests.
     */
    private static String createOrderViaPost(String customerId, String itemsJson) {
        String body = buildCreateBody(customerId, itemsJson);
        setupContext('POST', '/services/apexrest/orders/', body);
        OrderRestController.ApiResponse resp = OrderRestController.createOrder();
        return resp.orderId;
    }

    // -----------------------------------------------------------------------
    // POST — createOrder() success
    // -----------------------------------------------------------------------

    @isTest
    static void post_validRequest_returns201WithSuccess() {
        Contact c = getCustomer();
        String body = buildCreateBody(c.Id, singleItemJson());
        setupContext('POST', '/services/apexrest/orders/', body);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.createOrder();
        Test.stopTest();

        System.assertEquals(true, resp.success,
            'POST with a valid body must return success=true.');
        System.assertEquals(201, RestContext.response.statusCode,
            'HTTP status must be 201 Created.');
        System.assertNotEquals(null, resp.orderId,
            'Response must include the new Order Id.');
        System.assertEquals('Pending', resp.status,
            'Newly created order must have status Pending.');
    }

    @isTest
    static void post_multipleItems_subtotalAndGrandTotalAreCorrect() {
        Contact c = getCustomer();
        String body = buildCreateBody(c.Id, multiItemJson());
        setupContext('POST', '/services/apexrest/orders/', body);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.createOrder();
        Test.stopTest();

        System.assertEquals(true, resp.success,
            'POST with multiple items must return success=true.');
        // Burger: 1 × $8 = $8; Fries: 2 × $3 = $6 → subtotal = $14
        System.assertEquals(14.00, resp.subtotal,
            'Subtotal should be $14 for the two-item order.');
        System.assertNotEquals(null, resp.deliveryCharge,
            'Delivery charge must be present in the response.');
        System.assertEquals(resp.subtotal + resp.deliveryCharge, resp.grandTotal,
            'Grand total must equal subtotal + delivery charge.');
    }

    // -----------------------------------------------------------------------
    // POST — createOrder() error cases
    // -----------------------------------------------------------------------

    @isTest
    static void post_nullBody_returns400() {
        setupContext('POST', '/services/apexrest/orders/', null);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.createOrder();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'POST with null body must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 for a missing request body.');
    }

    @isTest
    static void post_invalidJson_returns400() {
        setupContext('POST', '/services/apexrest/orders/', '{not: valid json!!}');

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.createOrder();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'POST with invalid JSON must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 for malformed JSON.');
    }

    @isTest
    static void post_missingCustomerId_returns400() {
        String body = '{"customerId":null,"items":' + singleItemJson() + '}';
        setupContext('POST', '/services/apexrest/orders/', body);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.createOrder();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'POST without a customerId must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 when customerId is missing.');
    }

    @isTest
    static void post_emptyItemsList_returns400() {
        Contact c = getCustomer();
        String body = buildCreateBody(c.Id, '[]');
        setupContext('POST', '/services/apexrest/orders/', body);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.createOrder();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'POST with an empty items list must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 for an empty items array.');
    }

    // -----------------------------------------------------------------------
    // PUT — updateOrderStatus() success
    // -----------------------------------------------------------------------

    @isTest
    static void put_validStatusUpdate_returns200WithSuccess() {
        Contact c = getCustomer();
        // Create an order first
        String orderId = createOrderViaPost(c.Id, singleItemJson());

        // Pending → Accepted is a valid transition
        String putBody = '{"status":"Accepted"}';
        setupContext('PUT', '/services/apexrest/orders/' + orderId, putBody);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.updateOrderStatus();
        Test.stopTest();

        System.assertEquals(true, resp.success,
            'PUT with a valid status must return success=true.');
        System.assertEquals(200, RestContext.response.statusCode,
            'HTTP status must be 200 for a successful status update.');
        System.assertEquals('Accepted', resp.status,
            'Response status must reflect the updated value.');
    }

    @isTest
    static void put_pendingToCancelled_returns200() {
        Contact c = getCustomer();
        String orderId = createOrderViaPost(c.Id, singleItemJson());

        String putBody = '{"status":"Cancelled"}';
        setupContext('PUT', '/services/apexrest/orders/' + orderId, putBody);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.updateOrderStatus();
        Test.stopTest();

        System.assertEquals(true, resp.success,
            'Pending → Cancelled must return success=true.');
        System.assertEquals(200, RestContext.response.statusCode,
            'HTTP status should be 200 for Pending → Cancelled.');
    }

    // -----------------------------------------------------------------------
    // PUT — updateOrderStatus() error cases
    // -----------------------------------------------------------------------

    @isTest
    static void put_missingOrderIdInUrl_returns400() {
        // URL ends at /orders/ — no orderId segment
        String putBody = '{"status":"Accepted"}';
        setupContext('PUT', '/services/apexrest/orders/', putBody);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.updateOrderStatus();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'PUT without an orderId in the URL must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 when orderId is missing from the URL.');
    }

    @isTest
    static void put_invalidOrderIdFormat_returns400() {
        String putBody = '{"status":"Accepted"}';
        setupContext('PUT', '/services/apexrest/orders/NOTANID', putBody);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.updateOrderStatus();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'PUT with an invalid orderId format must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 for an invalid orderId format.');
    }

    @isTest
    static void put_nullBody_returns400() {
        Contact c = getCustomer();
        String orderId = createOrderViaPost(c.Id, singleItemJson());

        setupContext('PUT', '/services/apexrest/orders/' + orderId, null);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.updateOrderStatus();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'PUT with null body must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 for a missing PUT body.');
    }

    @isTest
    static void put_missingStatusField_returns400() {
        Contact c = getCustomer();
        String orderId = createOrderViaPost(c.Id, singleItemJson());

        // Body present but status is blank
        setupContext('PUT', '/services/apexrest/orders/' + orderId, '{"status":""}');

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.updateOrderStatus();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'PUT with a blank status must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 for a blank status value.');
    }

    // -----------------------------------------------------------------------
    // GET — getOrder() success
    // -----------------------------------------------------------------------

    @isTest
    static void get_validOrderId_returns200WithOrderDetails() {
        Contact c = getCustomer();
        String orderId = createOrderViaPost(c.Id, singleItemJson());

        setupContext('GET', '/services/apexrest/orders/' + orderId, null);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.getOrder();
        Test.stopTest();

        System.assertEquals(true, resp.success,
            'GET with a valid orderId must return success=true.');
        System.assertEquals(200, RestContext.response.statusCode,
            'HTTP status must be 200 for a found order.');
        System.assertEquals(orderId, resp.orderId,
            'Returned orderId must match the requested order.');
        System.assertNotEquals(null, resp.items,
            'Items list must be present in the GET response.');
        System.assertEquals(1, resp.items.size(),
            'One order item should be present in the response.');
    }

    @isTest
    static void get_validOrder_deliveryChargeIsCorrect() {
        Contact c = getCustomer();
        // Single item: 2 × $9.50 = $19.00
        String orderId = createOrderViaPost(c.Id, singleItemJson());

        setupContext('GET', '/services/apexrest/orders/' + orderId, null);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.getOrder();
        Test.stopTest();

        System.assertEquals(true, resp.success, 'GET must return success=true.');
        System.assertEquals(19.00, resp.subtotal,
            'Subtotal should be 2 × $9.50 = $19.00.');
        Decimal expectedCharge = DeliveryChargeCalculator.calculate(19.00);
        System.assertEquals(expectedCharge, resp.deliveryCharge,
            'Delivery charge must match the calculator output for $19 subtotal.');
    }

    // -----------------------------------------------------------------------
    // GET — getOrder() error cases
    // -----------------------------------------------------------------------

    @isTest
    static void get_missingOrderIdInUrl_returns400() {
        setupContext('GET', '/services/apexrest/orders/', null);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.getOrder();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'GET without an orderId in the URL must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 when orderId is missing.');
    }

    @isTest
    static void get_invalidOrderIdFormat_returns400() {
        setupContext('GET', '/services/apexrest/orders/BADFORMAT', null);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.getOrder();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'GET with an invalid orderId format must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 for an invalid orderId format.');
    }

    @isTest
    static void get_nonExistentOrderId_returns404() {
        // Insert and delete an order to obtain a well-formed but non-existent Id.
        Contact c = getCustomer();
        Order__c phantom = new Order__c(Customer__c = c.Id, Status__c = 'Pending');
        insert phantom;
        Id phantomId = phantom.Id;
        delete phantom;

        setupContext('GET', '/services/apexrest/orders/' + phantomId, null);

        Test.startTest();
        OrderRestController.ApiResponse resp = OrderRestController.getOrder();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'GET for a non-existent order must return success=false.');
        System.assertEquals(404, RestContext.response.statusCode,
            'HTTP status must be 404 when the order is not found.');
    }
}