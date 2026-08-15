import { LightningElement, api, wire } from 'lwc';
import getCarePlanSummary from '@salesforce/apex/CareLedgerService.getCarePlanSummary';
import getPendingClaims from '@salesforce/apex/CareLedgerService.getPendingClaims';
import approveClaim from '@salesforce/apex/CareLedgerService.approveClaim';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    {
        label: 'Care Worker',
        fieldName: 'Care_Worker_Name__c'
    },
    {
        label: 'Service Date',
        fieldName: 'Service_Date__c',
        type: 'date'
    },
    {
        label: 'Hours',
        fieldName: 'Hours_Delivered__c',
        type: 'number'
    },
    {
        label: 'Hourly Rate',
        fieldName: 'Hourly_Rate__c',
        type: 'currency'
    },
    {
        label: 'Claim Amount',
        fieldName: 'Total_Claim_Amount__c',
        type: 'currency'
    },
    {
        type: 'button',
        typeAttributes: {
            label: 'Approve',
            name: 'approve',
            title: 'Approve claim',
            variant: 'brand'
        }
    }
];

export default class CareBudgetDashboard extends LightningElement {
    @api recordId;

    plan;
    claims = [];
    columns = COLUMNS;
    wiredPlanResult;
    wiredClaimsResult;

    @wire(getCarePlanSummary, { carePlanId: '$recordId' })
    wiredPlan(result) {
        this.wiredPlanResult = result;

        if (result.data) {
            this.plan = result.data;
        } else if (result.error) {
            this.showError(result.error);
        }
    }

    @wire(getPendingClaims, { carePlanId: '$recordId' })
    wiredClaims(result) {
        this.wiredClaimsResult = result;

        if (result.data) {
            this.claims = result.data;
        } else if (result.error) {
            this.showError(result.error);
        }
    }

    get remainingBalance() {
        if (!this.plan) {
            return 0;
        }

        const allocation = this.plan.Total_Allocation__c || 0;
        const spent = this.plan.Total_Spent__c || 0;

        return allocation - spent;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const claimId = event.detail.row.Id;

        if (actionName !== 'approve') {
            return;
        }

        approveClaim({ claimId })
            .then(() => {
                this.showSuccess('Claim approved and ledger updated.');

                return Promise.all([
                    refreshApex(this.wiredPlanResult),
                    refreshApex(this.wiredClaimsResult)
                ]);
            })
            .catch((error) => {
                this.showError(error);
            });
    }

    showSuccess(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message,
                variant: 'success'
            })
        );
    }

    showError(error) {
        const message =
            error?.body?.message || 'An unexpected error occurred.';

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message,
                variant: 'error'
            })
        );
    }
}
