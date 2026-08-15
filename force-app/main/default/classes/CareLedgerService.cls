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
            Status__c
        FROM Care_Claim__c
        WHERE Funding_Allocation__r.Care_Plan__c = :carePlanId
        AND Status__c = 'Submitted'
        ORDER BY Service_Date__c ASC
    ];
}

    @AuraEnabled
    public static void approveClaim(Id claimId) {
        if (claimId == null) {
            throw new AuraHandledException('A claim ID is required.');
        }

        Care_Claim__c claim = [
            SELECT
                Id,
                Status__c,
                Total_Claim_Amount__c,
                Funding_Allocation__c,
                Funding_Allocation__r.Care_Plan__c,
                Funding_Allocation__r.Allocated_Amount__c,
                Funding_Allocation__r.Spent_Amount__c
            FROM Care_Claim__c
            WHERE Id = :claimId
            LIMIT 1
        ];

        if (claim.Status__c != 'Submitted') {
            throw new AuraHandledException(
                'Only submitted claims can be approved.'
            );
        }

        Funding_Allocation__c allocation = [
            SELECT
                Id,
                Allocated_Amount__c,
                Committed_Amount__c,
                Spent_Amount__c,
                Care_Plan__c
            FROM Funding_Allocation__c
            WHERE Id = :claim.Funding_Allocation__c
            FOR UPDATE
        ];

        Decimal allocatedAmount = valueOrZero(
            allocation.Allocated_Amount__c
        );
        Decimal committedAmount = valueOrZero(
            allocation.Committed_Amount__c
        );
        Decimal spentAmount = valueOrZero(
            allocation.Spent_Amount__c
        );
        Decimal claimAmount = valueOrZero(
            claim.Total_Claim_Amount__c
        );

        Decimal availableAmount =
            allocatedAmount - committedAmount - spentAmount;

        if (claimAmount > availableAmount) {
            throw new AuraHandledException(
                'Approval failed: claim exceeds available funding.'
            );
        }

        claim.Status__c = 'Approved';

        allocation.Spent_Amount__c = spentAmount + claimAmount;

        Ledger_Entry__c ledgerEntry = new Ledger_Entry__c(
            Funding_Allocation__c = allocation.Id,
            Reference_Claim__c = claim.Id,
            Entry_Type__c = 'Claim Debit',
            Amount__c = claimAmount,
            Transaction_Timestamp__c = System.now()
        );

        update claim;
        update allocation;
        insert ledgerEntry;

        Care_Plan__c carePlan = [
            SELECT Id, Total_Spent__c
            FROM Care_Plan__c
            WHERE Id = :allocation.Care_Plan__c
            LIMIT 1
            FOR UPDATE
        ];

        carePlan.Total_Spent__c =
            valueOrZero(carePlan.Total_Spent__c) + claimAmount;

        update carePlan;
    }

    private static Decimal valueOrZero(Decimal inputValue) {
        return inputValue == null ? 0 : inputValue;
    }
}
