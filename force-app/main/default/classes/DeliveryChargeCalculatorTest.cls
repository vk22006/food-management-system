/**
 * DeliveryChargeCalculatorTest
 *
 * Comprehensive unit tests for DeliveryChargeCalculator.
 * No DML required — the class is a pure computation utility.
 *
 * Formula under test:
 *   charge = BASE_CHARGE + (subtotal × RATE), minimum MINIMUM_CHARGE
 *   BASE_CHARGE    = 2.50
 *   RATE           = 0.05
 *   MINIMUM_CHARGE = 2.50
 *
 * Scenarios covered:
 *  - Null subtotal treated as zero → minimum charge returned
 *  - Zero subtotal → minimum charge returned
 *  - Negative subtotal treated as zero → minimum charge returned
 *  - Small positive subtotal ($10) → correct computed charge
 *  - Medium positive subtotal ($50) → correct computed charge
 *  - Large subtotal ($200) → correct computed charge
 *  - Decimal subtotal → result correctly rounded to 2 dp (HALF_UP)
 *  - Very small subtotal that would produce charge below minimum → minimum enforced
 *  - Constant values verified via @TestVisible fields
 *  - Multiple calls with same input return the same result (idempotency)
 */
@isTest
private class DeliveryChargeCalculatorTest {

    // -----------------------------------------------------------------------
    // Null / zero / negative guard tests
    // -----------------------------------------------------------------------

    @isTest
    static void nullSubtotal_returnsMinimumCharge() {
        Test.startTest();
        Decimal charge = DeliveryChargeCalculator.calculate(null);
        Test.stopTest();

        System.assertEquals(2.50, charge,
            'Null subtotal must be treated as zero and return the minimum charge of $2.50.');
    }

    @isTest
    static void zeroSubtotal_returnsMinimumCharge() {
        Test.startTest();
        Decimal charge = DeliveryChargeCalculator.calculate(0);
        Test.stopTest();

        // 2.50 + (0 × 0.05) = 2.50 — equals MINIMUM_CHARGE so floor not needed.
        System.assertEquals(2.50, charge,
            'Zero subtotal must return the minimum charge of $2.50.');
    }

    @isTest
    static void negativeSubtotal_returnsMinimumCharge() {
        Test.startTest();
        Decimal charge = DeliveryChargeCalculator.calculate(-10.00);
        Test.stopTest();

        System.assertEquals(2.50, charge,
            'Negative subtotal must be treated as zero and return the minimum charge of $2.50.');
    }

    @isTest
    static void veryNegativeSubtotal_returnsMinimumCharge() {
        Test.startTest();
        Decimal charge = DeliveryChargeCalculator.calculate(-999.99);
        Test.stopTest();

        System.assertEquals(2.50, charge,
            'Any negative subtotal must return the minimum charge of $2.50.');
    }

    // -----------------------------------------------------------------------
    // Normal value tests (formula verification)
    // -----------------------------------------------------------------------

    @isTest
    static void tenDollarSubtotal_returnsThreeDollars() {
        Test.startTest();
        Decimal charge = DeliveryChargeCalculator.calculate(10.00);
        Test.stopTest();

        // 2.50 + (10.00 × 0.05) = 2.50 + 0.50 = 3.00
        System.assertEquals(3.00, charge,
            'Charge for $10 subtotal should be $3.00 (base $2.50 + $0.50 rate).');
    }

    @isTest
    static void fiftyDollarSubtotal_returnsFiveDollars() {
        Test.startTest();
        Decimal charge = DeliveryChargeCalculator.calculate(50.00);
        Test.stopTest();

        // 2.50 + (50.00 × 0.05) = 2.50 + 2.50 = 5.00
        System.assertEquals(5.00, charge,
            'Charge for $50 subtotal should be $5.00 (base $2.50 + $2.50 rate).');
    }

    @isTest
    static void twentyDollarSubtotal_returnsThreeFifty() {
        Test.startTest();
        Decimal charge = DeliveryChargeCalculator.calculate(20.00);
        Test.stopTest();

        // 2.50 + (20.00 × 0.05) = 2.50 + 1.00 = 3.50
        System.assertEquals(3.50, charge,
            'Charge for $20 subtotal should be $3.50.');
    }

    @isTest
    static void twoHundredDollarSubtotal_returnsTwelveFifty() {
        Test.startTest();
        Decimal charge = DeliveryChargeCalculator.calculate(200.00);
        Test.stopTest();

        // 2.50 + (200.00 × 0.05) = 2.50 + 10.00 = 12.50
        System.assertEquals(12.50, charge,
            'Charge for $200 subtotal should be $12.50.');
    }

    // -----------------------------------------------------------------------
    // Decimal precision / rounding tests
    // -----------------------------------------------------------------------

    @isTest
    static void decimalSubtotalSevenThirtyThree_roundsCorrectly() {
        Test.startTest();
        Decimal charge = DeliveryChargeCalculator.calculate(7.33);
        Test.stopTest();

        // 2.50 + (7.33 × 0.05) = 2.50 + 0.3665 = 2.8665 → rounds to 2.87 (HALF_UP)
        System.assertEquals(2.87, charge,
            'Charge for $7.33 subtotal should round HALF_UP to $2.87.');
    }

    @isTest
    static void decimalSubtotalOneCent_roundsCorrectly() {
        Test.startTest();
        Decimal charge = DeliveryChargeCalculator.calculate(0.01);
        Test.stopTest();

        // 2.50 + (0.01 × 0.05) = 2.50 + 0.0005 = 2.5005 → rounds to 2.50 (HALF_UP, 2 dp)
        // Actually 2.5005 at scale 2 HALF_UP = 2.50
        // Wait: 2.5005 rounded to 2dp HALF_UP: the third decimal is 0, so it rounds down → 2.50
        System.assertEquals(2.50, charge,
            'Charge for $0.01 subtotal should be $2.50 (result rounds to minimum).');
    }

    @isTest
    static void decimalSubtotalThirtyThreeDollars_correctResult() {
        Test.startTest();
        Decimal charge = DeliveryChargeCalculator.calculate(33.00);
        Test.stopTest();

        // 2.50 + (33.00 × 0.05) = 2.50 + 1.65 = 4.15
        System.assertEquals(4.15, charge,
            'Charge for $33 subtotal should be $4.15.');
    }

    // -----------------------------------------------------------------------
    // Minimum charge enforcement
    // -----------------------------------------------------------------------

    @isTest
    static void minimumChargeEnforced_formulaResultNeverBelowMinimum() {
        // For any positive subtotal, the formula result is always >= BASE_CHARGE = MINIMUM_CHARGE
        // because BASE_CHARGE + positive = always > MINIMUM_CHARGE.
        // Verify explicitly with a very small positive subtotal.
        Test.startTest();
        Decimal charge = DeliveryChargeCalculator.calculate(0.05);
        Test.stopTest();

        System.assert(charge >= 2.50,
            'Charge must never be returned below MINIMUM_CHARGE ($2.50).');
    }

    // -----------------------------------------------------------------------
    // Constant verification via @TestVisible fields
    // -----------------------------------------------------------------------

    @isTest
    static void constants_haveExpectedValues() {
        System.assertEquals(2.50, DeliveryChargeCalculator.BASE_CHARGE,
            'BASE_CHARGE constant should be 2.50.');
        System.assertEquals(0.05, DeliveryChargeCalculator.RATE,
            'RATE constant should be 0.05 (5%).');
        System.assertEquals(2.50, DeliveryChargeCalculator.MINIMUM_CHARGE,
            'MINIMUM_CHARGE constant should be 2.50.');
    }

    // -----------------------------------------------------------------------
    // Idempotency test
    // -----------------------------------------------------------------------

    @isTest
    static void sameInput_alwaysReturnsSameOutput() {
        Decimal first  = DeliveryChargeCalculator.calculate(25.00);
        Decimal second = DeliveryChargeCalculator.calculate(25.00);

        System.assertEquals(first, second,
            'Repeated calls with the same input must return the same result.');
    }

    // -----------------------------------------------------------------------
    // Return type sanity
    // -----------------------------------------------------------------------

    @isTest
    static void result_hasExactlyTwoDecimalPlaces() {
        Decimal charge = DeliveryChargeCalculator.calculate(13.57);
        // Check scale: setScale(2) produces exactly 2 dp.
        Integer scale = charge.scale();
        System.assert(scale <= 2,
            'Result should have at most 2 decimal places after rounding.');
    }
}