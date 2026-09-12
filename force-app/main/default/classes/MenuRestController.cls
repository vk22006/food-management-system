/**
 * MenuRestController
 *
 * Apex REST resource that exposes Restaurant Menu Item data for external
 * consumers (Postman, Experience Cloud, third-party integrations).
 *
 * Base URL: /services/apexrest/menu/
 *
 * Supported operations:
 *   GET /services/apexrest/menu/
 *       Returns all available Menu_Item__c records across all restaurants.
 *
 *   GET /services/apexrest/menu/{restaurantId}
 *       Returns available Menu_Item__c records for the specified Restaurant__c.
 *
 * Response format: ApiResponse wrapper with a list of MenuItemDto objects.
 *
 * Security:
 *   - without sharing: REST resource called by integration user via Connected
 *     App. SOQL uses WITH USER_MODE to enforce field-level security.
 *   - Input restaurantId is validated as a 15/18-char alphanumeric Id before
 *     being used as a SOQL bind variable.
 *
 * Satisfies project requirement: Section 8 "GET - Get restaurant menu".
 */
@RestResource(urlMapping='/menu/*')
global without sharing class MenuRestController {

    // -----------------------------------------------------------------------
    // Response DTOs
    // -----------------------------------------------------------------------

    /** Standard API response envelope. */
    global class ApiResponse {
        global Boolean         success;
        global String          message;
        global List<MenuItemDto> menuItems;

        global ApiResponse(Boolean success, String message, List<MenuItemDto> items) {
            this.success   = success;
            this.message   = message;
            this.menuItems = items != null ? items : new List<MenuItemDto>();
        }
    }

    /** Serialisable representation of a single Menu_Item__c record. */
    global class MenuItemDto {
        global String  id;
        global String  name;
        global String  category;
        global Decimal price;
        global Boolean available;
        global String  restaurantId;
        global String  restaurantName;
    }

    // -----------------------------------------------------------------------
    // HTTP handlers
    // -----------------------------------------------------------------------

    /**
     * Returns available menu items, optionally filtered by restaurant.
     *
     * URL examples:
     *   GET /services/apexrest/menu/
     *   GET /services/apexrest/menu/001xx000003GYk0AAG
     *
     * @return ApiResponse containing matched MenuItemDto records.
     */
    @HttpGet
    global static ApiResponse getMenu() {
        RestRequest  req  = RestContext.request;
        RestResponse resp = RestContext.response;

        try {
            String restaurantId = extractSegmentFromUri(req.requestURI, '/menu/');

            List<Menu_Item__c> items;
            if (String.isNotBlank(restaurantId)) {
                // Validate the Id format before using it in SOQL.
                if (!isValidSalesforceId(restaurantId)) {
                    resp.statusCode = 400;
                    return new ApiResponse(false,
                        'Invalid restaurantId format. Provide a 15 or 18 character Salesforce Id.',
                        null);
                }
                items = [
                    SELECT Id, Name, Category__c, Price__c, Availability__c,
                           Restaurant__c, Restaurant__r.Name
                    FROM   Menu_Item__c
                    WHERE  Restaurant__c  = :restaurantId
                    AND    Availability__c = true
                    WITH USER_MODE
                    ORDER BY Category__c, Name
                ];
            } else {
                items = [
                    SELECT Id, Name, Category__c, Price__c, Availability__c,
                           Restaurant__c, Restaurant__r.Name
                    FROM   Menu_Item__c
                    WHERE  Availability__c = true
                    WITH USER_MODE
                    ORDER BY Restaurant__r.Name, Category__c, Name
                ];
            }

            List<MenuItemDto> dtos = toMenuItemDtos(items);
            resp.statusCode = 200;
            String message  = dtos.isEmpty() ? 'No available menu items found.' : null;
            return new ApiResponse(true, message, dtos);

        } catch (QueryException queryEx) {
            resp.statusCode = 500;
            return new ApiResponse(false,
                'An error occurred while retrieving menu items: ' + queryEx.getMessage(),
                null);
        } catch (Exception ex) {
            resp.statusCode = 500;
            return new ApiResponse(false,
                'Unexpected error: ' + ex.getMessage(),
                null);
        }
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /**
     * Converts a list of Menu_Item__c records to MenuItemDto objects.
     * No SOQL or DML; pure mapping.
     */
    private static List<MenuItemDto> toMenuItemDtos(List<Menu_Item__c> items) {
        List<MenuItemDto> dtos = new List<MenuItemDto>();
        for (Menu_Item__c item : items) {
            MenuItemDto dto    = new MenuItemDto();
            dto.id             = item.Id;
            dto.name           = item.Name;
            dto.category       = item.Category__c;
            dto.price          = item.Price__c;
            dto.available      = item.Availability__c;
            dto.restaurantId   = item.Restaurant__c;
            dto.restaurantName = item.Restaurant__r?.Name;
            dtos.add(dto);
        }
        return dtos;
    }

    /**
     * Extracts the path segment after basePath from a request URI.
     * Returns null when no segment is present.
     *
     * Example: URI = /services/apexrest/menu/0012X000  basePath = /menu/
     *          returns '0012X000'
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
        // Strip query string if present.
        Integer queryIdx = segment.indexOf('?');
        if (queryIdx > -1) {
            segment = segment.substring(0, queryIdx);
        }
        segment = segment.trim();
        return String.isBlank(segment) ? null : segment;
    }

    /**
     * Returns true when the string is a 15 or 18-character alphanumeric Id.
     */
    private static Boolean isValidSalesforceId(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        return Pattern.matches('[a-zA-Z0-9]{15}|[a-zA-Z0-9]{18}', value);
    }
}