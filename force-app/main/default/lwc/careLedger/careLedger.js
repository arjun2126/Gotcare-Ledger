import { LightningElement, api, wire } from 'lwc';
import getPendingClaims from '@salesforce/apex/CareLedgerService.getPendingClaims';
import approveClaim from '@salesforce/apex/CareLedgerService.approveClaim';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class CareLedger extends LightningElement {
    @api recordId;

    claims = [];
    error;
    isLoading = false;
    wiredClaimsResult;

    columns = [
        {
            label: 'Claim',
            fieldName: 'Name',
            type: 'text'
        },
        {
            label: 'Care Worker',
            fieldName: 'Care_Worker_Name__c',
            type: 'text'
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
            label: 'Status',
            fieldName: 'Status__c',
            type: 'text'
        },
        {
            type: 'button',
            typeAttributes: {
                label: 'Approve',
                name: 'approve',
                variant: 'brand'
            }
        }
    ];

    @wire(getPendingClaims, { carePlanId: '$recordId' })
    wiredClaims(result) {
        this.wiredClaimsResult = result;

        if (result.data) {
            this.claims = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = this.reduceError(result.error);
            this.claims = [];
        }
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName !== 'approve') {
            return;
        }

        this.isLoading = true;

        try {
            await approveClaim({ claimId: row.Id });

            this.showToast(
                'Success',
                'Claim approved and ledger entry created.',
                'success'
            );

            await refreshApex(this.wiredClaimsResult);
        } catch (error) {
            this.showToast(
                'Approval failed',
                this.reduceError(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }

        return (
            error?.body?.message ||
            error?.message ||
            'Unexpected error'
        );
    }
}
