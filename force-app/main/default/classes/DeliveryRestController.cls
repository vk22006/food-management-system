/**
 * DeliveryRestController
 *
 * Apex REST resource for Delivery__c tracking. Allows external consumers
 * (Postman, Experience Cloud portal, mobile apps) to track the delivery
 * status for a given order or delivery record.
 *
 * Base URL: /services/apexrest/deliveries/
 *
 * Supported operations:
 *
 *   GET /services/apexrest/deliveries/{deliveryId}
 *       Returns the Delivery__c record by its own Id.
 *
 *   GET /services/apexrest/deliveries/?orderId={orderId}
 *       Returns the Delivery__c record linked to the specified Order__c.
 *
 * Response format: ApiResponse wrapper with a DeliveryTrackingDto.
 *
 * Security:
 *   - without sharing: integration-facing REST resource. All SOQL uses
 *     WITH USER_MODE to enforce field-level security.
 *   - All user-supplied Id values are validated before use in SOQL.
 *
 */
@RestResource(urlMapping='/deliveries/*')
global without sharing class DeliveryRestController {

    // -----------------------------------------------------------------------
    // Response DTOs
    // -----------------------------------------------------------------------

    /** Standard API response envelope. */
    global class ApiResponse {
        global Boolean          success;
        global String           message;
        global DeliveryTrackingDto delivery;
    }

    /** Full delivery tracking payload returned to the caller. */
    global class DeliveryTrackingDto {
        global String deliveryId;
        global String deliveryStatus;
        global String deliveryDate;
        global String deliveryPartnerId;
        global String deliveryPartnerName;
        global String orderId;
        global String orderName;
        global String orderStatus;
        global Decimal orderSubtotal;
        global Decimal deliveryCharge;
        global Decimal grandTotal;
    }

    // -----------------------------------------------------------------------
    // HTTP handler
    // -----------------------------------------------------------------------

    /**
     * Returns delivery tracking details for a Delivery__c record or the
     * Delivery linked to an Order__c.
     *
     * URL examples:
     *   GET /services/apexrest/deliveries/a01xx000001AbCdAAK
     *   GET /services/apexrest/deliveries/?orderId=a00xx000001AbCdAAK
     *
     * @return ApiResponse containing DeliveryTrackingDto or an error message.
     */
    @HttpGet
    global static ApiResponse trackDelivery() {
        RestRequest  req  = RestContext.request;
        RestResponse resp = RestContext.response;
        ApiResponse  response = new ApiResponse();

        try {
            // Determine lookup strategy: path segment = deliveryId;
            // query param orderId = look up via Order.
            String pathSegment = extractSegmentFromUri(req.requestURI, '/deliveries/');
            String orderIdParam = req.params?.get('orderId');

            List<Delivery__c> deliveries;

            if (String.isNotBlank(pathSegment)) {
                // ---- Lookup by Delivery Id ----
                if (!isValidSalesforceId(pathSegment)) {
                    resp.statusCode  = 400;
                    response.success = false;
                    response.message =
                        'Invalid deliveryId format. Provide a 15 or 18 character Salesforce Id.';
                    return response;
                }
                deliveries = [
                    SELECT Id, Name, Status__c, Delivery_Date__c,
                           Delivery_Partner__c, Delivery_Partner__r.Name,
                           Order__c,
                           Order__r.Name, Order__r.Status__c,
                           Order__r.Total_Amount__c
                    FROM   Delivery__c
                    WHERE  Id = :pathSegment
                    WITH USER_MODE
                    LIMIT  1
                ];

            } else if (String.isNotBlank(orderIdParam)) {
                // ---- Lookup by Order Id ----
                if (!isValidSalesforceId(orderIdParam)) {
                    resp.statusCode  = 400;
                    response.success = false;
                    response.message =
                        'Invalid orderId format. Provide a 15 or 18 character Salesforce Id.';
                    return response;
                }
                deliveries = [
                    SELECT Id, Name, Status__c, Delivery_Date__c,
                           Delivery_Partner__c, Delivery_Partner__r.Name,
                           Order__c,
                           Order__r.Name, Order__r.Status__c,
                           Order__r.Total_Amount__c
                    FROM   Delivery__c
                    WHERE  Order__c = :orderIdParam
                    WITH USER_MODE
                    ORDER BY CreatedDate DESC
                    LIMIT  1
                ];

            } else {
                resp.statusCode  = 400;
                response.success = false;
                response.message =
                    'Provide a delivery Id in the URL path or an orderId query parameter.';
                return response;
            }

            if (deliveries.isEmpty()) {
                resp.statusCode  = 404;
                response.success = false;
                response.message = 'No delivery record found for the provided identifier.';
                return response;
            }

            Delivery__c delivery = deliveries[0];
            Decimal subtotal = (delivery.Order__r?.Total_Amount__c != null)
                ? delivery.Order__r.Total_Amount__c
                : 0;
            Decimal deliveryCharge = DeliveryChargeCalculator.calculate(subtotal);

            DeliveryTrackingDto dto     = new DeliveryTrackingDto();
            dto.deliveryId              = delivery.Id;
            dto.deliveryStatus          = delivery.Status__c;
            dto.deliveryDate            = delivery.Delivery_Date__c != null
                ? String.valueOf(delivery.Delivery_Date__c)
                : null;
            dto.deliveryPartnerId       = delivery.Delivery_Partner__c;
            dto.deliveryPartnerName     = delivery.Delivery_Partner__r?.Name;
            dto.orderId                 = delivery.Order__c;
            dto.orderName               = delivery.Order__r?.Name;
            dto.orderStatus             = delivery.Order__r?.Status__c;
            dto.orderSubtotal           = subtotal;
            dto.deliveryCharge          = deliveryCharge;
            dto.grandTotal              = subtotal + deliveryCharge;

            resp.statusCode    = 200;
            response.success   = true;
            response.delivery  = dto;

        } catch (QueryException queryEx) {
            resp.statusCode  = 500;
            response.success = false;
            response.message =
                'An error occurred while retrieving delivery: ' + queryEx.getMessage();
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