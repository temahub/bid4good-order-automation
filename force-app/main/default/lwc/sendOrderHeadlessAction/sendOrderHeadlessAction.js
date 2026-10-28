import { LightningElement, api } from 'lwc';
import sendOrderEmail from '@salesforce/apex/OrderEmailService.sendOrderEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/**
 * @description Headless Lightning Web Component action responsible for triggering order confirmation
 * email dispatch directly from a record page action button.
 */
export default class SendOrderHeadlessAction extends LightningElement {
  /**
   * The Salesforce record ID of the current Order__c record.
   * @type {string}
   */
  @api recordId;

  /**
   * Flag indicating whether an email dispatch request is currently in progress.
   * @type {boolean}
   */
  isSending = false;

  /**
   * Public API method invoked automatically by the Salesforce action framework
   * when the user triggers the headless action. Prevents concurrent duplicate submissions.
   * @returns {void}
   */
  @api
  invoke() {
    if (this.isSending) {
      return;
    }

    this.isSending = true;
    this.sendOrder();
  }

  /**
   * Asynchronously calls the Apex email service, manages loading state,
   * and dispatches success or error Toast notifications to the user interface.
   * @returns {Promise<void>}
   */
  async sendOrder() {
    try {
      if (!this.recordId) {
        throw new Error('The Order record ID is unavailable.');
      }

      await sendOrderEmail({
        orderId: this.recordId
      });

      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Email sent',
          message: 'The Order email was queued successfully.',
          variant: 'success'
        })
      );
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Email failed',
          message:
            error?.body?.message ||
            error?.message ||
            'An unexpected error occurred.',
          variant: 'error',
          mode: 'sticky'
        })
      );
    } finally {
      this.isSending = false;
    }
  }
}
