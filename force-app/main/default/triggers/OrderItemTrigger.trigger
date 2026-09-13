/**
 * OrderItemTrigger
 *
 * Thin trigger on Order_Item__c. Fires after any DML operation that can
 * affect the total value of a parent Order and delegates all business logic
 * to OrderTotalCalculator.recalculate().
 *
 * Covered events:
 *  - after insert   : new item added to an Order
 *  - after update   : item Quantity__c or Price__c changed
 *  - after delete   : item removed from an Order
 *  - after undelete : previously deleted item restored
 *
 * Bulk-safe: collects all affected Order IDs into a single Set and performs
 * exactly one SOQL + one DML via OrderTotalCalculator regardless of batch size.
 *
 * Companion class: OrderTotalCalculator
 */
trigger OrderItemTrigger on Order_Item__c (
    after insert,
    after update,
    after delete,
    after undelete
) {
    Set<Id> orderIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUndelete) {
        for (Order_Item__c item : Trigger.new) {
            if (item.Order__c != null) {
                orderIds.add(item.Order__c);
            }
        }
    } else if (Trigger.isDelete) {
        for (Order_Item__c item : Trigger.old) {
            if (item.Order__c != null) {
                orderIds.add(item.Order__c);
            }
        }
    } else if (Trigger.isUpdate) {
        for (Order_Item__c item : Trigger.new) {
            if (item.Order__c != null) {
                orderIds.add(item.Order__c);
            }
            Order_Item__c oldItem = Trigger.oldMap.get(item.Id);
            if (oldItem != null && oldItem.Order__c != null && oldItem.Order__c != item.Order__c) {
                orderIds.add(oldItem.Order__c);
            }
        }
    }

    if (!orderIds.isEmpty()) {
        OrderTotalCalculator.recalculate(orderIds);
    }
}