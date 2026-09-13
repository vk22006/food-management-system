/**
 * OrderTotalCalculator
 *
 * Service class that recalculates Order__c.Total_Amount__c by aggregating
 * the line totals (Quantity__c × Price__c) of all child Order_Item__c records
 * for a given set of Orders.
 *
 * Design:
 *  - One SOQL query and one DML update per call, regardless of record volume.
 *  - Sets Total_Amount__c to 0 for Orders whose last item was deleted.
 *  - Callable from OrderItemTrigger, Batch Apex, invocable methods, and REST controllers.
 *  - with sharing enforces Salesforce record-level security for direct UI invocations.
 *
 * Companion trigger: OrderItemTrigger.trigger
 */
public with sharing class OrderTotalCalculator {

    public static void recalculate(Set<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) {
            return;
        }

        // Initialise every requested Order to 0 so that Orders with no remaining
        // items (e.g. after the last item is deleted) are correctly zeroed out.
        Map<Id, Decimal> orderTotals = new Map<Id, Decimal>();
        for (Id orderId : orderIds) {
            orderTotals.put(orderId, 0);
        }

        // Query Quantity__c and Price__c directly and sum in Apex.
        // Using Quantity__c × Price__c avoids aggregate SOQL on formula fields.
        // Separate query from for-loop to avoid the "Variable does not exist:
        // tmpVar1" platform bug with inline SOQL on Master-Detail bind variables.
        List<Order_Item__c> items = [
            SELECT Id, Order__c, Quantity__c, Price__c
            FROM Order_Item__c
            WHERE Order__c IN :orderIds
        ];

        for (Order_Item__c item : items) {
            Decimal qty   = item.Quantity__c != null ? item.Quantity__c : 0;
            Decimal price = item.Price__c    != null ? item.Price__c    : 0;
            orderTotals.put(item.Order__c, orderTotals.get(item.Order__c) + (qty * price));
        }

        // Build the update list and perform a single DML call.
        List<Order__c> ordersToUpdate = new List<Order__c>();
        for (Id orderId : orderTotals.keySet()) {
            ordersToUpdate.add(new Order__c(
                Id              = orderId,
                Total_Amount__c = orderTotals.get(orderId)
            ));
        }

        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
        }
    }
}