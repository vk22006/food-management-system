/**
 * MenuRestControllerTest
 *
 * Comprehensive test coverage for MenuRestController.
 *
 * Scenarios covered:
 *  - GET /menu/ with no filter returns all available items across all restaurants
 *  - GET /menu/ returns only items where Availability__c = true
 *  - GET /menu/{restaurantId} returns available items for that restaurant only
 *  - GET /menu/{restaurantId} where the restaurant has no matching items returns
 *    success=true with an empty menuItems list
 *  - GET /menu/{invalidId} where the Id is not a valid 15/18-char Salesforce Id
 *    returns HTTP 400 with success=false
 *  - Response status code is 200 on success
 *  - Response contains MenuItemDto with correct field mappings
 *  - GET with a well-formed but non-existent restaurantId returns empty list (success=true)
 */
@isTest
private class MenuRestControllerTest {

    // -----------------------------------------------------------------------
    // Test data setup
    // -----------------------------------------------------------------------

    @TestSetup
    static void makeData() {
        // Two restaurants
        Restaurant__c r1 = new Restaurant__c(Name = 'Pizza Palace');
        Restaurant__c r2 = new Restaurant__c(Name = 'Burger Barn');
        insert new List<Restaurant__c>{ r1, r2 };

        // Menu items: 2 available for r1, 1 unavailable for r1, 1 available for r2
        List<Menu_Item__c> items = new List<Menu_Item__c>{
            new Menu_Item__c(
                Name           = 'Margherita Pizza',
                Category__c    = 'Main Course',
                Price__c       = 12.00,
                Availability__c = true,
                Restaurant__c  = r1.Id
            ),
            new Menu_Item__c(
                Name           = 'Garlic Bread',
                Category__c    = 'Appetizer',
                Price__c       = 4.50,
                Availability__c = true,
                Restaurant__c  = r1.Id
            ),
            new Menu_Item__c(
                Name           = 'Seasonal Special',
                Category__c    = 'Main Course',
                Price__c       = 15.00,
                Availability__c = false,     // NOT available — should be excluded
                Restaurant__c  = r1.Id
            ),
            new Menu_Item__c(
                Name           = 'Classic Burger',
                Category__c    = 'Main Course',
                Price__c       = 8.00,
                Availability__c = true,
                Restaurant__c  = r2.Id
            )
        };
        insert items;
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private static RestRequest buildGetRequest(String uri) {
        RestRequest req = new RestRequest();
        req.requestURI  = uri;
        req.httpMethod  = 'GET';
        return req;
    }

    private static void setupContext(String uri) {
        RestContext.request  = buildGetRequest(uri);
        RestContext.response = new RestResponse();
    }

    private static Id getRestaurantId(String name) {
        return [SELECT Id FROM Restaurant__c WHERE Name = :name LIMIT 1].Id;
    }

    // -----------------------------------------------------------------------
    // GET all menu items (no restaurant filter)
    // -----------------------------------------------------------------------

    @isTest
    static void getAllMenu_returnsOnlyAvailableItems() {
        setupContext('/services/apexrest/menu/');

        Test.startTest();
        MenuRestController.ApiResponse resp = MenuRestController.getMenu();
        Test.stopTest();

        System.assertEquals(true, resp.success,
            'Response success should be true when menu items are found.');
        System.assertEquals(200, RestContext.response.statusCode,
            'HTTP status code should be 200.');

        // 3 available items total (2 from r1, 1 from r2); the unavailable one is excluded.
        System.assertEquals(3, resp.menuItems.size(),
            'All 3 available items should be returned across both restaurants.');
    }

    @isTest
    static void getAllMenu_unavailableItemsAreExcluded() {
        setupContext('/services/apexrest/menu/');

        Test.startTest();
        MenuRestController.ApiResponse resp = MenuRestController.getMenu();
        Test.stopTest();

        for (MenuRestController.MenuItemDto dto : resp.menuItems) {
            System.assertEquals(true, dto.available,
                'Every returned item should have Availability__c = true. Found: ' + dto.name);
        }
    }

    @isTest
    static void getAllMenu_dtoFieldsArePopulated() {
        setupContext('/services/apexrest/menu/');

        Test.startTest();
        MenuRestController.ApiResponse resp = MenuRestController.getMenu();
        Test.stopTest();

        System.assert(!resp.menuItems.isEmpty(), 'Menu items list should not be empty.');
        MenuRestController.MenuItemDto first = resp.menuItems[0];
        System.assertNotEquals(null, first.id,          'DTO id should be set.');
        System.assertNotEquals(null, first.name,        'DTO name should be set.');
        System.assertNotEquals(null, first.restaurantId,'DTO restaurantId should be set.');
    }

    // -----------------------------------------------------------------------
    // GET menu by restaurantId
    // -----------------------------------------------------------------------

    @isTest
    static void getMenuByRestaurant_returnsOnlyItemsForThatRestaurant() {
        Id r1Id = getRestaurantId('Pizza Palace');
        setupContext('/services/apexrest/menu/' + r1Id);

        Test.startTest();
        MenuRestController.ApiResponse resp = MenuRestController.getMenu();
        Test.stopTest();

        System.assertEquals(true, resp.success,
            'Response success should be true for a valid restaurantId.');
        System.assertEquals(200, RestContext.response.statusCode,
            'HTTP status code should be 200.');

        // Only 2 available items belong to Pizza Palace.
        System.assertEquals(2, resp.menuItems.size(),
            'Only the 2 available Pizza Palace items should be returned.');

        for (MenuRestController.MenuItemDto dto : resp.menuItems) {
            System.assertEquals(String.valueOf(r1Id), dto.restaurantId,
                'All returned items should belong to the queried restaurant.');
        }
    }

    @isTest
    static void getMenuByRestaurant_secondRestaurant_returnsCorrectItems() {
        Id r2Id = getRestaurantId('Burger Barn');
        setupContext('/services/apexrest/menu/' + r2Id);

        Test.startTest();
        MenuRestController.ApiResponse resp = MenuRestController.getMenu();
        Test.stopTest();

        System.assertEquals(true, resp.success,
            'Response should succeed for Burger Barn.');
        System.assertEquals(1, resp.menuItems.size(),
            'Only the 1 available Burger Barn item should be returned.');
        System.assertEquals('Classic Burger', resp.menuItems[0].name,
            'The returned item should be the Classic Burger.');
    }

    @isTest
    static void getMenuByRestaurant_noMatchingItems_returnsSuccessWithEmptyList() {
        // Create a restaurant with no menu items.
        Restaurant__c emptyRestaurant = new Restaurant__c(Name = 'Empty Eatery');
        insert emptyRestaurant;

        setupContext('/services/apexrest/menu/' + emptyRestaurant.Id);

        Test.startTest();
        MenuRestController.ApiResponse resp = MenuRestController.getMenu();
        Test.stopTest();

        System.assertEquals(true, resp.success,
            'Response should be success=true even when no items exist for the restaurant.');
        System.assertEquals(200, RestContext.response.statusCode,
            'HTTP status code should be 200 for an empty result.');
        System.assertNotEquals(null, resp.menuItems,
            'menuItems list should not be null.');
        System.assertEquals(0, resp.menuItems.size(),
            'menuItems list should be empty for a restaurant with no available items.');
    }

    // -----------------------------------------------------------------------
    // Invalid restaurantId format
    // -----------------------------------------------------------------------

    @isTest
    static void getMenuByRestaurant_invalidIdFormat_returns400() {
        setupContext('/services/apexrest/menu/NOT_A_VALID_ID');

        Test.startTest();
        MenuRestController.ApiResponse resp = MenuRestController.getMenu();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'Response success should be false for an invalid restaurantId format.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status code should be 400 for an invalid restaurantId.');
        System.assertNotEquals(null, resp.message,
            'An error message should be returned.');
    }

    @isTest
    static void getMenuByRestaurant_tooShortId_returns400() {
        // 14-character ID (not 15 or 18) should be rejected.
        setupContext('/services/apexrest/menu/00Q12345678901');

        Test.startTest();
        MenuRestController.ApiResponse resp = MenuRestController.getMenu();
        Test.stopTest();

        System.assertEquals(false, resp.success,
            'A 14-char Id should fail validation and return success=false.');
        System.assertEquals(400, RestContext.response.statusCode,
            'HTTP status should be 400 for an invalid Id length.');
    }

    @isTest
    static void getMenuByRestaurant_wellFormedNonExistentId_returnsEmptyList() {
        // A syntactically valid 18-char Id that does not match any Restaurant.
        // Build one from a known prefix (001 = Account) that is not a Restaurant.
        Id accountTypeId = '001000000000000AAA';
        setupContext('/services/apexrest/menu/' + accountTypeId);

        Test.startTest();
        MenuRestController.ApiResponse resp = MenuRestController.getMenu();
        Test.stopTest();

        // Valid SF Id format, but no Menu Items belong to that "restaurant" (it's an Account Id).
        System.assertEquals(true, resp.success,
            'A well-formed but non-existent Id should not cause an error — just an empty result.');
        System.assertEquals(0, resp.menuItems.size(),
            'No items should be returned for a non-existent restaurant Id.');
    }

    // -----------------------------------------------------------------------
    // menuItems list is never null
    // -----------------------------------------------------------------------

    @isTest
    static void response_menuItemsListIsNeverNull() {
        setupContext('/services/apexrest/menu/');

        Test.startTest();
        MenuRestController.ApiResponse resp = MenuRestController.getMenu();
        Test.stopTest();

        System.assertNotEquals(null, resp.menuItems,
            'ApiResponse.menuItems must never be null.');
    }
}