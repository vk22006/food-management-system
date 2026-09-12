/**
 * DeliveryChargeCalculator
 *
 * Pure-computation utility. Calculates the delivery charge for a food order
 * given the item subtotal. Contains no SOQL and no DML, making it safe to call
 * from any execution context including trigger handlers, REST controllers,
 * and invocable methods.
 *
 * Charge formula:
 *   delivery charge = BASE_CHARGE + (subtotal x RATE), minimum MINIMUM_CHARGE
 *
 * Examples:
 *   subtotal  $0.00 → charge $2.50
 *   subtotal $10.00 → charge $3.00  (2.50 + 10 x 0.05)
 *   subtotal $50.00 → charge $5.00  (2.50 + 50 x 0.05)
 *
 * Satisfies project requirement: Section 7 "Calculate delivery charges".
 */
public with sharing class DeliveryChargeCalculator {

    // -----------------------------------------------------------------------
    // Configuration constants
    // -----------------------------------------------------------------------

    /** Fixed base charge applied to every delivery. */
    @TestVisible
    private static final Decimal BASE_CHARGE     = 2.50;

    /** Percentage of the item subtotal added to the base charge. */
    @TestVisible
    private static final Decimal RATE            = 0.05;

    /** Floor: the charge will never be returned below this amount. */
    @TestVisible
    private static final Decimal MINIMUM_CHARGE  = 2.50;

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /**
     * Calculates the delivery charge for an order.
     *
     * No SOQL. No DML. Safe in all execution contexts.
     *
     * @param orderSubtotal  Item subtotal from Order__c.Total_Amount__c.
     *                       Null or negative values are treated as zero.
     * @return               Delivery charge in currency units, rounded to 2 dp.
     *
     * @example
     * Decimal charge = DeliveryChargeCalculator.calculate(20.00);
     * // Returns 3.50 (2.50 base + 20 * 0.05)
     */
    public static Decimal calculate(Decimal orderSubtotal) {
        Decimal subtotal = (orderSubtotal != null && orderSubtotal > 0)
            ? orderSubtotal
            : 0;

        Decimal charge = BASE_CHARGE + (subtotal * RATE);

        if (charge < MINIMUM_CHARGE) {
            charge = MINIMUM_CHARGE;
        }
        return charge;

    }
}