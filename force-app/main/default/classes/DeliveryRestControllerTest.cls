/**
 * DeliveryRestControllerTest
 *
 * Comprehensive test coverage for DeliveryRestController.
 *
 * Scenarios covered:
 *  - GET /deliveries/{deliveryId}    - returns DeliveryTrackingDto for a valid Delivery Id
 *  - GET /deliveries/?orderId={id}   - returns DeliveryTrackingDto when querying by Order Id
 *  - GET /deliveries/{invalidId}     - invalid Delivery Id format returns HTTP 400
 *  - GET /deliveries/?orderId={bad}  - invalid orderId format returns HTTP 400
 *  - GET /deliveries/                - no identifiers supplied returns HTTP 400
 *  - GET /deliveries/{noMatch}       - well-formed but non-existent Delivery Id returns HTTP 404
 *  - GET /deliveries/?orderId={none} - well-formed but non-existent Order Id returns HTTP 404
 *  - Response DTO fields are populated correctly
 *  - Delivery charge and grand total are computed correctly in the response
 */
@isTest
private class DeliveryRestControllerTest {

    // -----------------------------------------------------------------------
    // Test data setup
    // -----------------------------------------------------------------------

    @TestSetup
    static void makeData() {
        Contact customer = new Contact(
            LastName = 'DeliveryCtrlTestCustomer',
            Email    = 'delivery.ctrl@example.com'
        );
        insert customer;

        // Status = 'Pending' avoids triggering Order_Create_Delivery_On_Accept flow.
        Order__c order = new Order__c(
            Customer__c = customer.Id,
            Status__c   = 'Pending'
        );
        insert order;

        // Insert an Order Item so Total_Amount__c is populated by the trigger.
        insert new Order_Item__c(
            Order__c        = order.Id,
            Product_Name__c = 'Test Item',
            Quantity__c     = 2,
            Price__c        = 10.00
        );

        // Create a Delivery linked to the order.
        insert new Delivery__c(
            Order__c  = order.Id,
            Status__c = 'Assigned'
        );
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private static Delivery__c getDelivery() {
        return [SELECT Id, Order__c, Status__c FROM Delivery__c LIMIT 1];
    }

    private static Order__c getOrder() {
        return [SELECT Id, Total_Amount__c FROM Order__c LIMIT 1];
    }

    /**
     * Set up a GET /deliveries/{pathSegment} request.
     * RestRequest.params is a final field initialised to an empty Map by the
     * RestRequest constructor; no assignment to params is required here.
     */
    private static void setupGetByPath(String pathSegment) {
        RestRequest req = new RestRequest();
        req.requestURI  = '/services/apexrest/deliveries/' + pathSegment;
        req.httpMethod  = 'GET';
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    /**
     * Set up a GET /deliveries/?orderId={orderId} request.
     * RestRequest.params is final - we cannot reassign it.
     * We mutate the pre-existing Map instance by calling put() directly.
     */
    private static void setupGetByOrderId(String orderId) {
        RestRequest req = new RestRequest();
        req.requestURI  = '/services/apexrest/deliveries/';
        req.httpMethod  = 'GET';
        req.params.put('orderId', orderId);
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    /**
     * Set up a GET /deliveries/ request with no path segment and no query params.
     * RestRequest.params is a final field initialised to an empty Map by the
     * RestRequest constructor; no assignment to params is required here.
     */
    private static void setupGetNoIdentifiers() {
        RestRequest req = new RestRequest();
        req.requestURI  = '/services/apexrest/deliveries/';
        req.httpMethod  = 'GET';
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    // -----------------------------------------------------------------------
    // GET by Delivery Id (path segment) - success
    // -----------------------------------------------------------------------

    @isTest
    static void getByDeliveryId_validId_returns200WithDto() {
        Delivery__c delivery = getDelivery();
        setupGetByPath(delivery.Id);

        Test.startTest();
        DeliveryRestController.ApiResponse resp = DeliveryRestController.trackDelivery();
        Test.stopTest();

        System.assertEquals(true, resp.success,
            'GET by valid deliveryId must return success=true.');
        System.assertEquals(200, RestContext.response.statusCode,
            'HTTP status must be 200 for a found delivery.');
        System.assertNotEquals(null, resp.delivery,
            'DeliveryTrackingDto must be present in the response.');
        System.assertEquals(String.valueOf(delivery.Id), resp.delivery.deliveryId,
            'DTO deliveryId must match the queried delivery.');
        System.assertEquals('Assigned', resp.delivery.deliveryStatus,
            'DTO deliveryStatus must match the inserted Delivery record.');
    }

    @isTest
    static void getByDeliveryId_dtoOrderIdIsPopulated() {
        Delivery__c delivery = getDelivery();
        Order__c    order    = getOrder();
        setupGetByPath(delivery.Id);

        Test.startTest();
        DeliveryRestController.ApiResponse resp = DeliveryRestController.trackDelivery();
        Test.stopTest();

        System.assertNotEquals(null, resp.delivery.orderId,
            'DTO orderId should be populated.');
        System.assertEquals(String.valueOf(order.Id), resp.delivery.orderId,
            'DTO orderId must match the parent Order.');
    }

    @isTest
    static void getByDeliveryId_deliveryChargeAndGrandTotalAreCorrect() {
        Delivery__c delivery = getDelivery();
        Order__c    order    = getOrder();
        setupGetByPath(delivery.Id);

        Test.startTest();
        DeliveryRestController.ApiResponse resp = DeliveryRestController.trackDelivery();
        Test.stopTest();

        // Trigger populated Total_Amount__c = 2 x $10 = $20
        Decimal expectedCharge = DeliveryChargeCalculator.calculate(order.Total_Amount__c);
        System.assertEquals(expectedCharge, resp.delivery.deliveryCharge,
            'Delivery charge in DTO must match DeliveryChargeCalculator.calculate(subtotal).');
        System.assertEquals(
            resp.delivery.orderSubtotal + resp.delivery.deliveryCharge,
            resp.delivery.grandTotal,
            'Grand total must equal orderSubtotal + deliveryCharge.'
        );
    }

    // -----------------------------------------------------------------------
    // GET by Order Id (query parameter) - success
    // -----------------------------------------------------------------------

    @isTest
    static void getByOrderId_validId_returns200WithDto() {
        Order__c order = getOrder();
        setupGetByOrderId(order.Id);

        Test.startTest();
        DeliveryRestController.ApiResponse resp = DeliveryRestController.trackDelivery();
        Test.stopTest();

        System.assertEquals(true, resp.success,
            'GET by valid orderId must return success=true.');
        System.assertEquals(200, RestContext.response.statusCode,
            'HTTP status must be 200 for a found delivery via orderId.');
        System.assertNotEquals(null, resp.delivery,
            'DeliveryTrackingDto must be present when querying by orderId.');
        System.assertEquals(String.valueOf(order.Id), resp.delivery.orderId,
            'DTO orderId must match the queried Order.');
    }

    @isTest
    static void getByOrderId_deliveryStatusIsCorrect() {
        Order__c order = getOrder();
        setupGetByOrderId(order.Id);

        Test.startTest();
        DeliveryRestController.ApiResponse resp = DeliveryRestController.trackDelivery();
        Test.stopTest();

        System.assertEquals('Assigned', resp.delivery.deliveryStatus,
            'Delivery status in DTO should be Assigned (as inserted in test setup).');
    }

    @isTest
    static void getByOrderId_deliveryIdIsPopulated() {
        Delivery__c delivery = getDelivery();
        Order__c    order    = getOrder();
        setupGetByOrderId(order.Id);

        Test.startTest();
        DeliveryRestController.ApiResponse resp = DeliveryRestController.trackDelivery();
        Test.stopTest();

        System.assertEquals(String.valueOf(delivery.Id), resp.delivery.deliveryId,
            'DTO deliveryId must match the Delivery record linked to the Order.');
    }

    // -----------------------------------------------------------------------
    // Invalid identifier format - 400
    // -----------------------------------------------------------------------

    @isTest
    static void getByDeliveryId_invalidIdFormat_returns400() {
        setupGetByPath('INVALID_FORMAT_123');

        Test.startTest();
        DeliveryRestController.ApiResponse resp = DeliveryRestController.trackDelivery();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'GET with an invalid deliveryId format must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 for an invalid deliveryId format.');
        System.assertNotEquals(null, resp.message,
            'An error message must be returned for an invalid Id format.');
    }

    @isTest
    static void getByOrderId_invalidIdFormat_returns400() {
        setupGetByOrderId('NOT_VALID_AT_ALL');

        Test.startTest();
        DeliveryRestController.ApiResponse resp = DeliveryRestController.trackDelivery();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'GET with an invalid orderId format must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 for an invalid orderId query param.');
    }

    // -----------------------------------------------------------------------
    // No identifiers supplied - 400
    // -----------------------------------------------------------------------

    @isTest
    static void getNoIdentifiers_returns400() {
        setupGetNoIdentifiers();

        Test.startTest();
        DeliveryRestController.ApiResponse resp = DeliveryRestController.trackDelivery();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'GET with no deliveryId and no orderId must return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status must be 400 when no identifier is supplied.');
        System.assertNotEquals(null, resp.message,
            'An error message must be returned when no identifier is provided.');
    }

    // -----------------------------------------------------------------------
    // Non-existent identifiers - 404
    // -----------------------------------------------------------------------

    @isTest
    static void getByDeliveryId_nonExistentId_returns404() {
        // Obtain a well-formed but deleted Delivery Id.
        Delivery__c phantom = getDelivery();
        Id phantomId = phantom.Id;
        delete phantom;

        setupGetByPath(phantomId);

        Test.startTest();
        DeliveryRestController.ApiResponse resp = DeliveryRestController.trackDelivery();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'GET for a deleted Delivery must return success=false.');
        System.assertEquals(404, RestContext.response.statusCode,
            'HTTP status must be 404 for a non-existent deliveryId.');
    }

    @isTest
    static void getByOrderId_nonExistentId_returns404() {
        // Obtain a well-formed but deleted Order Id.
        Order__c phantom = getOrder();
        Id phantomOrderId = phantom.Id;

        // First detach / delete the delivery so Order can be deleted.
        Delivery__c d = getDelivery();
        delete d;
        delete phantom;

        setupGetByOrderId(phantomOrderId);

        Test.startTest();
        DeliveryRestController.ApiResponse resp = DeliveryRestController.trackDelivery();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'GET for a deleted Order should return success=false (no delivery found).');
        System.assertEquals(404, RestContext.response.statusCode,
            'HTTP status must be 404 when no delivery is found for the given orderId.');
    }

    // -----------------------------------------------------------------------
    // DTO never null on success
    // -----------------------------------------------------------------------

    @isTest
    static void response_deliveryDtoIsNeverNullOnSuccess() {
        Delivery__c delivery = getDelivery();
        setupGetByPath(delivery.Id);

        Test.startTest();
        DeliveryRestController.ApiResponse resp = DeliveryRestController.trackDelivery();
        Test.stopTest();

        System.assertEquals(true, resp.success, 'GET should succeed.');
        System.assertNotEquals(null, resp.delivery,
            'ApiResponse.delivery must never be null on a successful response.');
        System.assertNotEquals(null, resp.delivery.deliveryId,
            'DTO deliveryId must not be null.');
        System.assertNotEquals(null, resp.delivery.deliveryStatus,
            'DTO deliveryStatus must not be null.');
        System.assertNotEquals(null, resp.delivery.orderId,
            'DTO orderId must not be null.');
    }
}