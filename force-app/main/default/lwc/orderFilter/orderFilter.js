import { LightningElement, wire } from 'lwc';
import getAccountsWithOrders from '@salesforce/apex/OrderFilterController.getAccountsWithOrders';
import getAvailableMonthKeys from '@salesforce/apex/OrderFilterController.getAvailableMonthKeys';
import getOrdersForAccountAndMonth from '@salesforce/apex/OrderFilterController.getOrdersForAccountAndMonth';

const COLUMNS = [
  {
    label: 'Order Number',
    fieldName: 'recordUrl',
    type: 'url',
    typeAttributes: {
      label: { fieldName: 'Name' },
      target: '_self'
    }
  },
  {
    label: 'Payment Due Date',
    fieldName: 'Payment_Due_Date__c',
    type: 'date-local',
    typeAttributes: {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    }
  },
  {
    label: 'Total Amount',
    fieldName: 'Total_Amount__c',
    type: 'currency',
    typeAttributes: {
      currencyCode: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }
  }
];

export default class OrderFilter extends LightningElement {
  columns = COLUMNS;

  accountOptions = [];
  monthOptions = [];
  orderRows = [];

  selectedAccountId;
  selectedMonthKey;

  accountsLoaded = false;
  monthsLoaded = false;
  ordersLoaded = false;

  accountsError;
  monthsError;
  ordersError;

  wiredAccountsResult;
  wiredMonthsResult;
  wiredOrdersResult;

  @wire(getAccountsWithOrders)
  wiredAccounts(result) {
    this.wiredAccountsResult = result;

    const { data, error } = result;

    if (data) {
      this.accountOptions = data.map((account) => ({
        label: account.Name,
        value: account.Id
      }));

      this.accountsError = undefined;
      this.accountsLoaded = true;
    } else if (error) {
      this.accountOptions = [];
      this.accountsError = error;
      this.accountsLoaded = true;
    }
  }

  @wire(getAvailableMonthKeys, {
    accountId: '$selectedAccountId'
  })
  wiredMonths(result) {
    this.wiredMonthsResult = result;

    const { data, error } = result;

    if (data) {
      this.monthOptions = data.map((monthKey) => ({
        label: this.formatMonthLabel(monthKey),
        value: monthKey
      }));

      this.monthsError = undefined;
      this.monthsLoaded = true;
    } else if (error) {
      this.monthOptions = [];
      this.monthsError = error;
      this.monthsLoaded = true;
    }
  }

  @wire(getOrdersForAccountAndMonth, {
    accountId: '$selectedAccountId',
    monthKey: '$selectedMonthKey'
  })
  wiredOrders(result) {
    this.wiredOrdersResult = result;

    const { data, error } = result;

    if (data) {
      this.orderRows = data.map((order) => ({
        ...order,
        recordUrl: `/${order.Id}`
      }));

      this.ordersError = undefined;
      this.ordersLoaded = true;
    } else if (error) {
      this.orderRows = [];
      this.ordersError = error;
      this.ordersLoaded = true;
    }
  }

  handleAccountChange(event) {
    this.selectedAccountId = event.detail.value;

    // A previously selected month belongs to the old Account.
    this.selectedMonthKey = undefined;

    this.monthOptions = [];
    this.orderRows = [];

    this.monthsLoaded = false;
    this.ordersLoaded = false;

    this.monthsError = undefined;
    this.ordersError = undefined;
  }

  handleMonthChange(event) {
    this.selectedMonthKey = event.detail.value;

    this.orderRows = [];
    this.ordersLoaded = false;
    this.ordersError = undefined;
  }

  formatMonthLabel(monthKey) {
    const [year, month] = monthKey.split('-').map(Number);

    return new Intl.DateTimeFormat('en-US', {
      month: 'long',
      year: 'numeric'
    }).format(new Date(year, month - 1, 1));
  }

  get isAccountDisabled() {
    return !this.accountsLoaded || this.accountOptions.length === 0;
  }

  get isMonthDisabled() {
    return (
      !this.selectedAccountId ||
      !this.monthsLoaded ||
      this.monthOptions.length === 0
    );
  }

  get hasSelection() {
    return Boolean(this.selectedAccountId && this.selectedMonthKey);
  }

  get noAccountsFound() {
    return (
      this.accountsLoaded &&
      !this.accountsError &&
      this.accountOptions.length === 0
    );
  }

  get noMonthsFound() {
    return (
      Boolean(this.selectedAccountId) &&
      this.monthsLoaded &&
      !this.monthsError &&
      this.monthOptions.length === 0
    );
  }

  get showTable() {
    return (
      this.hasSelection &&
      this.ordersLoaded &&
      !this.ordersError &&
      this.orderRows.length > 0
    );
  }

  get showNoOrdersMessage() {
    return (
      this.hasSelection &&
      this.ordersLoaded &&
      !this.ordersError &&
      this.orderRows.length === 0
    );
  }

  get errorMessage() {
    const error = this.accountsError || this.monthsError || this.ordersError;

    if (!error) {
      return undefined;
    }

    return (
      error.body?.message ||
      error.message ||
      'An unexpected error occurred while loading data.'
    );
  }
}
