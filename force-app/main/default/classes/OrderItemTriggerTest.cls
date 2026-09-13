/**
 * OrderItemTriggerTest
 *
 * Comprehensive test coverage for OrderItemTrigger and OrderTotalCalculator.
 *
 * Scenarios covered:
 *  - Single item insert recalculates Total_Amount__c
 *  - Multiple items inserted for the same order sum correctly
 *  - Items inserted for multiple orders update each order independently
 *  - Updating an item's Quantity__c recalculates the total
 *  - Updating an item's Price__c recalculates the total
 *  - Deleting the only item zeroes the total
 *  - Deleting one of multiple items updates the total correctly
 *  - Undeleting a previously deleted item restores the total
 *  - Bulk insert of 200 items recalculates correctly
 *  - OrderTotalCalculator.recalculate() is a no-op for null/empty input
 */
@isTest
private class OrderItemTriggerTest {

    // -----------------------------------------------------------------------
    // Test data setup
    // -----------------------------------------------------------------------

    @TestSetup
    static void makeData() {
        Contact customer = new Contact(
            LastName = 'TriggerTestCustomer',
            Email    = 'trigger.test@example.com'
        );
        insert customer;

        // Two orders for multi-order tests
        List<Order__c> orders = new List<Order__c>{
            new Order__c(Customer__c = customer.Id, Status__c = 'Pending'),
            new Order__c(Customer__c = customer.Id, Status__c = 'Pending')
        };
        insert orders;
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private static Id firstOrderId() {
        return [SELECT Id FROM Order__c ORDER BY CreatedDate ASC LIMIT 1].Id;
    }

    private static List<Id> allOrderIds() {
        List<Id> ids = new List<Id>();
        for (Order__c o : [SELECT Id FROM Order__c ORDER BY CreatedDate ASC]) {
            ids.add(o.Id);
        }
        return ids;
    }

    private static Decimal getTotal(Id orderId) {
        return [SELECT Total_Amount__c FROM Order__c WHERE Id = :orderId].Total_Amount__c;
    }

    // -----------------------------------------------------------------------
    // INSERT tests
    // -----------------------------------------------------------------------

    @isTest
    static void insertSingleItem_recalculatesTotal() {
        Id orderId = firstOrderId();

        Test.startTest();
        insert new Order_Item__c(
            Order__c        = orderId,
            Product_Name__c = 'Burger',
            Quantity__c     = 2,
            Price__c        = 8.00
        );
        Test.stopTest();

        System.assertEquals(
            16.00, getTotal(orderId),
            'Total_Amount__c should be 2 × $8 = $16 after inserting one item.'
        );
    }

    @isTest
    static void insertMultipleItemsSameOrder_sumsAllItems() {
        Id orderId = firstOrderId();

        Test.startTest();
        insert new List<Order_Item__c>{
            new Order_Item__c(Order__c = orderId, Product_Name__c = 'Pizza',    Quantity__c = 1, Price__c = 12.00),
            new Order_Item__c(Order__c = orderId, Product_Name__c = 'Beverage', Quantity__c = 2, Price__c =  3.00)
        };
        Test.stopTest();

        // 12.00 + (2 × 3.00) = 18.00
        System.assertEquals(
            18.00, getTotal(orderId),
            'Total_Amount__c should be 18.00 when two items are inserted for the same order.'
        );
    }

    @isTest
    static void insertItemsForMultipleOrders_updatesEachOrderIndependently() {
        List<Id> ids = allOrderIds();
        Id orderId1  = ids[0];
        Id orderId2  = ids[1];

        Test.startTest();
        insert new List<Order_Item__c>{
            new Order_Item__c(Order__c = orderId1, Product_Name__c = 'Pasta',   Quantity__c = 1, Price__c = 10.00),
            new Order_Item__c(Order__c = orderId2, Product_Name__c = 'Dessert', Quantity__c = 2, Price__c =  5.00)
        };
        Test.stopTest();

        System.assertEquals(
            10.00, getTotal(orderId1),
            'Order 1 total should be $10.00.'
        );
        System.assertEquals(
            10.00, getTotal(orderId2),
            'Order 2 total should be 2 × $5 = $10.00.'
        );
    }

    // -----------------------------------------------------------------------
    // UPDATE tests
    // -----------------------------------------------------------------------

    @isTest
    static void updateItemQuantity_recalculatesTotal() {
        Id orderId = firstOrderId();
        Order_Item__c item = new Order_Item__c(
            Order__c        = orderId,
            Product_Name__c = 'Steak',
            Quantity__c     = 1,
            Price__c        = 20.00
        );
        insert item;

        Test.startTest();
        item.Quantity__c = 3;
        update item;
        Test.stopTest();

        System.assertEquals(
            60.00, getTotal(orderId),
            'Total_Amount__c should be 3 × $20 = $60 after updating quantity.'
        );
    }

    @isTest
    static void updateItemPrice_recalculatesTotal() {
        Id orderId = firstOrderId();
        Order_Item__c item = new Order_Item__c(
            Order__c        = orderId,
            Product_Name__c = 'Salad',
            Quantity__c     = 2,
            Price__c        = 5.00
        );
        insert item;

        Test.startTest();
        item.Price__c = 7.50;
        update item;
        Test.stopTest();

        System.assertEquals(
            15.00, getTotal(orderId),
            'Total_Amount__c should be 2 × $7.50 = $15 after updating price.'
        );
    }

    @isTest
    static void updateBothQtyAndPrice_recalculatesTotal() {
        Id orderId = firstOrderId();
        Order_Item__c item = new Order_Item__c(
            Order__c        = orderId,
            Product_Name__c = 'Sushi',
            Quantity__c     = 1,
            Price__c        = 5.00
        );
        insert item;

        Test.startTest();
        item.Quantity__c = 4;
        item.Price__c    = 2.50;
        update item;
        Test.stopTest();

        System.assertEquals(
            10.00, getTotal(orderId),
            'Total_Amount__c should be 4 × $2.50 = $10 after updating both qty and price.'
        );
    }

    @isTest
    static void reparentItem_recalculatesBothOrders() {
        List<Id> ids = allOrderIds();
        Id orderId1  = ids[0];
        Id orderId2  = ids[1];

        Order_Item__c item1 = new Order_Item__c(Order__c = orderId1, Product_Name__c = 'Item 1', Quantity__c = 2, Price__c = 10.00);
        Order_Item__c item2 = new Order_Item__c(Order__c = orderId2, Product_Name__c = 'Item 2', Quantity__c = 1, Price__c = 25.00);
        insert new List<Order_Item__c>{ item1, item2 };

        System.assertEquals(20.00, getTotal(orderId1), 'Initial order 1 total should be 20.00');
        System.assertEquals(25.00, getTotal(orderId2), 'Initial order 2 total should be 25.00');

        Test.startTest();
        // Move item1 from order 1 to order 2
        item1.Order__c = orderId2;
        update item1;
        Test.stopTest();

        System.assertEquals(0, getTotal(orderId1), 'Order 1 total should be 0 after losing its only item.');
        System.assertEquals(45.00, getTotal(orderId2), 'Order 2 total should be 25 + 20 = 45.00 after gaining item1.');
    }

    // -----------------------------------------------------------------------
    // DELETE tests
    // -----------------------------------------------------------------------

    @isTest
    static void deleteOnlyItem_zeroeTotal() {
        Id orderId = firstOrderId();
        Order_Item__c item = new Order_Item__c(
            Order__c        = orderId,
            Product_Name__c = 'Soup',
            Quantity__c     = 3,
            Price__c        = 4.00
        );
        insert item;

        Test.startTest();
        delete item;
        Test.stopTest();

        Decimal total = getTotal(orderId);
        System.assertEquals(
            0, total,
            'Total_Amount__c should be 0 after deleting the only item.'
        );
    }

    @isTest
    static void deleteOneOfMultipleItems_updatesTotal() {
        Id orderId = firstOrderId();
        Order_Item__c item1 = new Order_Item__c(Order__c = orderId, Product_Name__c = 'A', Quantity__c = 1, Price__c = 10.00);
        Order_Item__c item2 = new Order_Item__c(Order__c = orderId, Product_Name__c = 'B', Quantity__c = 1, Price__c =  5.00);
        insert new List<Order_Item__c>{ item1, item2 };

        Test.startTest();
        delete item2;
        Test.stopTest();

        System.assertEquals(
            10.00, getTotal(orderId),
            'Total_Amount__c should be $10 after deleting item2 (which contributed $5).'
        );
    }

    // -----------------------------------------------------------------------
    // UNDELETE test
    // -----------------------------------------------------------------------

    @isTest
    static void undeleteItem_restoresTotal() {
        Id orderId = firstOrderId();
        Order_Item__c item = new Order_Item__c(
            Order__c        = orderId,
            Product_Name__c = 'Wrap',
            Quantity__c     = 2,
            Price__c        = 6.00
        );
        insert item;
        delete item; // Total goes to 0

        Test.startTest();
        undelete item;
        Test.stopTest();

        System.assertEquals(
            12.00, getTotal(orderId),
            'Total_Amount__c should be restored to 2 × $6 = $12 after undelete.'
        );
    }

    // -----------------------------------------------------------------------
    // BULK test
    // -----------------------------------------------------------------------

    @isTest
    static void bulkInsert200Items_recalculatesCorrectly() {
        Id orderId = firstOrderId();

        List<Order_Item__c> items = new List<Order_Item__c>();
        for (Integer i = 0; i < 200; i++) {
            items.add(new Order_Item__c(
                Order__c        = orderId,
                Product_Name__c = 'Item ' + i,
                Quantity__c     = 1,
                Price__c        = 1.00
            ));
        }

        Test.startTest();
        insert items;
        Test.stopTest();

        System.assertEquals(
            200.00, getTotal(orderId),
            'Bulk insert of 200 × $1 items should produce a total of $200.'
        );
    }

    @isTest
    static void bulkDelete200Items_zeroeTotal() {
        Id orderId = firstOrderId();
        List<Order_Item__c> items = new List<Order_Item__c>();
        for (Integer i = 0; i < 50; i++) {
            items.add(new Order_Item__c(
                Order__c        = orderId,
                Product_Name__c = 'Bulk ' + i,
                Quantity__c     = 1,
                Price__c        = 2.00
            ));
        }
        insert items;

        Test.startTest();
        delete items;
        Test.stopTest();

        System.assertEquals(
            0, getTotal(orderId),
            'Total_Amount__c should be 0 after bulk delete of all items.'
        );
    }

    // -----------------------------------------------------------------------
    // OrderTotalCalculator direct guard tests
    // -----------------------------------------------------------------------

    @isTest
    static void recalculate_nullInput_isNoOp() {
        Test.startTest();
        OrderTotalCalculator.recalculate(null);
        Test.stopTest();
        System.assert(true, 'recalculate(null) should complete without exception.');
    }

    @isTest
    static void recalculate_emptySet_isNoOp() {
        Test.startTest();
        OrderTotalCalculator.recalculate(new Set<Id>());
        Test.stopTest();
        System.assert(true, 'recalculate(empty set) should complete without exception.');
    }

    @isTest
    static void recalculate_multipleOrderIds_updatesAll() {
        List<Id> ids = allOrderIds();
        Id orderId1  = ids[0];
        Id orderId2  = ids[1];

        // Insert one item per order outside startTest to prime Total_Amount__c.
        insert new Order_Item__c(Order__c = orderId1, Product_Name__c = 'X', Quantity__c = 1, Price__c = 5.00);
        insert new Order_Item__c(Order__c = orderId2, Product_Name__c = 'Y', Quantity__c = 2, Price__c = 3.00);

        // Manually call recalculate with both order IDs.
        Test.startTest();
        OrderTotalCalculator.recalculate(new Set<Id>{ orderId1, orderId2 });
        Test.stopTest();

        System.assertEquals(5.00,  getTotal(orderId1), 'Order 1 total should be $5.');
        System.assertEquals(6.00,  getTotal(orderId2), 'Order 2 total should be 2 × $3 = $6.');
    }
}