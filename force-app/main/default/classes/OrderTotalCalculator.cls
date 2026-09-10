/**
 * OrderTotalCalculator
 *
 * Service class that recalculates Order__c.Total_Amount__c by aggregating
 * the Line_Total__c (Quantity__c * Price__c) values of all child Order_Item__c
 * records for a given set of Orders.
 *
 * Design:
 *  - One aggregate SOQL and one DML update per call, regardless of record volume.
 *  - Sets Total_Amount__c to 0 for Orders whose last item was deleted.
 *  - Callable from OrderItemTrigger, Batch Apex, invocable methods, and REST controllers.
 *  - with sharing enforces Salesforce record-level security for direct UI invocations.
 *
 * Companion trigger: OrderItemTrigger.trigger
 */
public with sharing class OrderTotalCalculator {

    /**
     * Recalculates Total_Amount__c on the specified Orders.
     *
     * For each Order ID in the provided set:
     *  - If related Order Items exist, Total_Amount__c = SUM(Line_Total__c).
     *  - If no Order Items remain, Total_Amount__c = 0.
     *
     * Bulk-safe: performs exactly one SOQL query and one DML statement
     * regardless of the number of Orders or Order Items involved.
     *
     * @param orderIds  Set of Order__c record IDs to recalculate.
     *                  Null or empty input is a no-op.
     */
    public static void recalculate(Set<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) {
            return;
        }

        // Aggregate line totals per Order in a single query.
        // Line_Total__c = Quantity__c * Price__c (formula, BlankAsZero).
        // WITH USER_MODE enforces CRUD/FLS on the read per API 67.0 security defaults.
        Map<Id, Decimal> totalByOrder = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Order__c orderId, SUM(Line_Total__c) lineTotal
            FROM   Order_Item__c
            WHERE  Order__c IN :orderIds
            WITH USER_MODE
            GROUP BY Order__c
        ]) {
            totalByOrder.put(
                (Id)      ar.get('orderId'),
                (Decimal) ar.get('lineTotal')
            );
        }

        // Build the update list.
        // Orders absent from the aggregate result have zero items remaining.
        List<Order__c> ordersToUpdate = new List<Order__c>();
        for (Id orderId : orderIds) {
            ordersToUpdate.add(new Order__c(
                Id              = orderId,
                Total_Amount__c = totalByOrder.containsKey(orderId)
                    ? totalByOrder.get(orderId)
                    : 0
            ));
        }

        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
        }
    }
}