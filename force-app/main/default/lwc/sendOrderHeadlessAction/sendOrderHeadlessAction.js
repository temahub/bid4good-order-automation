import { LightningElement, api } from 'lwc';
import sendOrderEmail from '@salesforce/apex/OrderEmailService.sendOrderEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SendOrderHeadlessAction extends LightningElement {
  @api recordId;

  isSending = false;

  @api
  invoke() {
    if (this.isSending) {
      return;
    }

    this.isSending = true;
    this.sendOrder();
  }

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
