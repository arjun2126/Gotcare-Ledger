public with sharing class CareLedgerService {
    @AuraEnabled(cacheable=true)
    public static Care_Plan__c getCarePlanSummary(Id carePlanId) {
        if (carePlanId == null) {
            return null;
        }

        return [
            SELECT
                Id,
                Name,
                Client_Name__c,
                Client__c,
                Total_Allocation__c,
                Total_Spent__c,
                Status__c
            FROM Care_Plan__c
            WHERE Id = :carePlanId
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Care_Claim__c> getPendingClaims(Id carePlanId) {
        if (carePlanId == null) {
            return new List<Care_Claim__c>();
        }

        return [
            SELECT
                Id,
                Name,
                Care_Worker_Name__c,
                Service_Date__c,
                Hours_Delivered__c,
                Hourly_Rate__c,
                Total_Claim_Amount__c,
                Status__c,
                Funding_Allocation__c,
                Funding_Allocation__r.Name
            FROM Care_Claim__c
            WHERE Funding_Allocation__r.Care_Plan__c = :carePlanId
            AND Status__c = 'Submitted'
            ORDER BY Service_Date__c ASC, CreatedDate ASC
        ];
    }

    @AuraEnabled
    public static void approveClaim(Id claimId) {
        if (claimId == null) {
            throwHandledError('A claim ID is required.');
        }

        Care_Claim__c claim = [
            SELECT
                Id,
                Status__c,
                Total_Claim_Amount__c,
                Funding_Allocation__c
            FROM Care_Claim__c
            WHERE Id = :claimId
            LIMIT 1
        ];

        if (claim.Status__c != 'Submitted') {
            throwHandledError(
                'Only submitted claims can be approved.'
            );
        }

        Funding_Allocation__c allocation = [
            SELECT
                Id,
                Care_Plan__c,
                Allocated_Amount__c,
                Committed_Amount__c,
                Spent_Amount__c
            FROM Funding_Allocation__c
            WHERE Id = :claim.Funding_Allocation__c
            FOR UPDATE
        ];

        Care_Plan__c carePlan = [
            SELECT
                Id,
                Total_Spent__c
            FROM Care_Plan__c
            WHERE Id = :allocation.Care_Plan__c
            FOR UPDATE
        ];

        Decimal allocatedAmount =
            valueOrZero(allocation.Allocated_Amount__c);

        Decimal committedAmount =
            valueOrZero(allocation.Committed_Amount__c);

        Decimal spentAmount =
            valueOrZero(allocation.Spent_Amount__c);

        Decimal claimAmount =
            valueOrZero(claim.Total_Claim_Amount__c);

        Decimal availableAmount =
            allocatedAmount - committedAmount - spentAmount;

        if (claimAmount <= 0) {
            throwHandledError(
                'Approval failed: claim amount must be greater than zero.'
            );
        }

        if (claimAmount > availableAmount) {
            throwHandledError(
                'Approval failed: claim exceeds available funding.'
            );
        }

        claim.Status__c = 'Approved';

        allocation.Spent_Amount__c =
            spentAmount + claimAmount;

        carePlan.Total_Spent__c =
            valueOrZero(carePlan.Total_Spent__c) + claimAmount;

        Ledger_Entry__c ledgerEntry = new Ledger_Entry__c(
            Funding_Allocation__c = allocation.Id,
            Reference_Claim__c = claim.Id,
            Entry_Type__c = 'Claim Approval',
            Amount__c = claimAmount,
            Transaction_Timestamp__c = System.now(),
            Effective_Date__c = Date.today(),
            Source_System__c = 'Salesforce',
            Reason__c = 'Approved care claim'
        );

        update claim;
        update allocation;
        update carePlan;
        insert ledgerEntry;
    }

    private static Decimal valueOrZero(Decimal inputValue) {
        return inputValue == null ? 0 : inputValue;
    }

    private static void throwHandledError(String message) {
        AuraHandledException error =
            new AuraHandledException(message);

        error.setMessage(message);
        throw error;
    }
}
