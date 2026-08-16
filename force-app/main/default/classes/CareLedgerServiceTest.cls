@IsTest
private class CareLedgerServiceTest {
    @TestSetup
    static void createTestData() {
        Care_Plan__c carePlan = new Care_Plan__c(
            Client_Name__c = 'Demo Client',
            Total_Allocation__c = 5000,
            Total_Spent__c = 0,
            Status__c = 'Active'
        );
        insert carePlan;

        Funding_Allocation__c allocation =
            new Funding_Allocation__c(
                Care_Plan__c = carePlan.Id,
                Category__c = 'Personal Support',
                Allocated_Amount__c = 3000,
                Committed_Amount__c = 0,
                Spent_Amount__c = 0
            );
        insert allocation;

        Care_Claim__c claim = new Care_Claim__c(
            Funding_Allocation__c = allocation.Id,
            Care_Worker_Name__c = 'Demo Care Worker',
            Service_Date__c = Date.today(),
            Hours_Delivered__c = 10,
            Hourly_Rate__c = 35,
            Status__c = 'Submitted'
        );
        insert claim;
    }

    @IsTest
    static void approveClaimCreatesLedgerEntry() {
        Care_Claim__c claim = [
            SELECT Id
            FROM Care_Claim__c
            LIMIT 1
        ];

        Test.startTest();
        CareLedgerService.approveClaim(claim.Id);
        Test.stopTest();

        Care_Claim__c updatedClaim = [
            SELECT Status__c
            FROM Care_Claim__c
            WHERE Id = :claim.Id
        ];

        System.assertEquals(
            'Approved',
            updatedClaim.Status__c
        );

        Ledger_Entry__c ledgerEntry = [
            SELECT
                Amount__c,
                Entry_Type__c,
                Reference_Claim__c,
                Effective_Date__c,
                Source_System__c,
                Reason__c
            FROM Ledger_Entry__c
            WHERE Reference_Claim__c = :claim.Id
            LIMIT 1
        ];

        System.assertEquals(350, ledgerEntry.Amount__c);
        System.assertEquals(
            'Claim Approval',
            ledgerEntry.Entry_Type__c
        );
        System.assertEquals(
            claim.Id,
            ledgerEntry.Reference_Claim__c
        );
        System.assertEquals(
            Date.today(),
            ledgerEntry.Effective_Date__c
        );
        System.assertEquals(
            'Salesforce',
            ledgerEntry.Source_System__c
        );
        System.assertEquals(
            'Approved care claim',
            ledgerEntry.Reason__c
        );
    }

    @IsTest
    static void claimExceedingBudgetIsRejected() {
        Care_Claim__c claim = [
            SELECT Id, Funding_Allocation__c
            FROM Care_Claim__c
            LIMIT 1
        ];

        Funding_Allocation__c allocation = [
            SELECT Id, Allocated_Amount__c
            FROM Funding_Allocation__c
            WHERE Id = :claim.Funding_Allocation__c
            LIMIT 1
        ];

        allocation.Allocated_Amount__c = 100;
        update allocation;

        Test.startTest();

        try {
            CareLedgerService.approveClaim(claim.Id);

            System.assert(
                false,
                'An oversized claim should have been rejected.'
            );
        } catch (AuraHandledException error) {
            System.assertEquals(
                'Approval failed: claim exceeds available funding.',
                error.getMessage()
            );
        }

        Test.stopTest();
    }
}
