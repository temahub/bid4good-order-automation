import { LightningElement, wire } from 'lwc';
import getAccountsWithOrders from '@salesforce/apex/OrderFilterController.getAccountsWithOrders';
import getAvailableMonthKeys from '@salesforce/apex/OrderFilterController.getAvailableMonthKeys';
import getOrdersForAccountAndMonth from '@salesforce/apex/OrderFilterController.getOrdersForAccountAndMonth';
import { refreshApex } from '@salesforce/apex';
import {
  subscribe,
  unsubscribe,
  onError,
  isEmpEnabled
} from 'lightning/empApi';

const CDC_CHANNELS = ['/data/AccountChangeEvent', '/data/Order__ChangeEvent'];

const REPLAY_FROM_TIP = -1;
const REFRESH_DEBOUNCE_MS = 300;

let empApiErrorListenerRegistered = false;

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

  subscriptions = {};
  pendingChannels = new Set();

  refreshTimer;
  refreshInProgress = false;
  refreshPending = false;

  cdcSubscriptionError;
  refreshError;

  connectedCallback() {
    this.registerEmpApiErrorListener();

    CDC_CHANNELS.forEach((channelName) => {
      this.subscribeToChannel(channelName);
    });
  }

  disconnectedCallback() {
    if (this.refreshTimer) {
      clearTimeout(this.refreshTimer);
      this.refreshTimer = undefined;
    }

    Object.values(this.subscriptions).forEach((subscription) => {
      unsubscribe(subscription, (response) => {
        if (!response?.successful) {
          console.warn('CDC unsubscribe was unsuccessful.');
        }
      });
    });

    this.subscriptions = {};
  }

  registerEmpApiErrorListener() {
    if (empApiErrorListenerRegistered) {
      return;
    }

    onError((error) => {
      console.error('EMP API error:', JSON.stringify(error));
    });

    empApiErrorListenerRegistered = true;
  }

  async subscribeToChannel(channelName) {
    if (
      this.subscriptions[channelName] ||
      this.pendingChannels.has(channelName)
    ) {
      return;
    }

    this.pendingChannels.add(channelName);

    try {
      const enabled = await isEmpEnabled();

      if (!enabled) {
        this.cdcSubscriptionError =
          'EMP API is not supported in this browser context.';
        return;
      }

      const subscription = await subscribe(
        channelName,
        REPLAY_FROM_TIP,
        (message) => {
          this.handleChangeEvent(channelName, message);
        }
      );

      // The component might have been removed while subscribing.
      if (!this.isConnected) {
        unsubscribe(subscription, () => {});
        return;
      }

      this.subscriptions[channelName] = subscription;

      console.info(`Subscribed to ${channelName}`);
    } catch (error) {
      this.cdcSubscriptionError = `${channelName}: ${this.getErrorText(error)}`;

      console.error(`Unable to subscribe to ${channelName}:`, error);
    } finally {
      this.pendingChannels.delete(channelName);
    }
  }

  handleChangeEvent(channelName, message) {
    if (!this.isConnected) {
      return;
    }

    const header = message?.data?.payload?.ChangeEventHeader;

    console.debug('CDC event received:', {
      channelName,
      changeType: header?.changeType,
      recordIds: header?.recordIds
    });

    this.scheduleDataRefresh();
  }

  scheduleDataRefresh() {
    if (this.refreshTimer) {
      clearTimeout(this.refreshTimer);
    }

    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.refreshTimer = setTimeout(() => {
      this.refreshTimer = undefined;
      this.refreshCurrentData();
    }, REFRESH_DEBOUNCE_MS);
  }

  hasProvisionedWireResult(result) {
    return Boolean(
      result && (result.data !== undefined || result.error !== undefined)
    );
  }

  async refreshCurrentData() {
    if (!this.isConnected) {
      return;
    }

    if (this.refreshInProgress) {
      this.refreshPending = true;
      return;
    }

    this.refreshInProgress = true;
    this.refreshError = undefined;

    try {
      // Refresh the Account picklist first.
      if (this.hasProvisionedWireResult(this.wiredAccountsResult)) {
        await refreshApex(this.wiredAccountsResult);
      }

      // Account selection may have been cleared after the refresh.
      if (
        this.selectedAccountId &&
        this.hasProvisionedWireResult(this.wiredMonthsResult)
      ) {
        await refreshApex(this.wiredMonthsResult);
      }

      // The selected month may also have been cleared.
      if (
        this.selectedAccountId &&
        this.selectedMonthKey &&
        this.hasProvisionedWireResult(this.wiredOrdersResult)
      ) {
        await refreshApex(this.wiredOrdersResult);
      }
    } catch (error) {
      this.refreshError = error;

      console.error('Unable to refresh Order Filter data:', error);
    } finally {
      this.refreshInProgress = false;

      if (this.refreshPending && this.isConnected) {
        this.refreshPending = false;
        this.scheduleDataRefresh();
      }
    }
  }

  getErrorText(error) {
    return error?.body?.message || error?.message || 'Unknown error';
  }

  @wire(getAccountsWithOrders)
  wiredAccounts(result) {
    this.wiredAccountsResult = result;

    const { data, error } = result;

    if (data) {
      this.accountOptions = data.map((account) => ({
        label: account.Name,
        value: account.Id
      }));

      if (
        this.selectedAccountId &&
        !data.some((account) => account.Id === this.selectedAccountId)
      ) {
        this.selectedAccountId = undefined;
        this.selectedMonthKey = undefined;

        this.monthOptions = [];
        this.orderRows = [];

        this.monthsLoaded = false;
        this.ordersLoaded = false;
      }

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

      if (
        this.selectedMonthKey &&
        !this.monthOptions.some(
          (option) => option.value === this.selectedMonthKey
        )
      ) {
        this.selectedMonthKey = undefined;
        this.orderRows = [];
        this.ordersLoaded = false;
      }

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
    const error =
      this.accountsError ||
      this.monthsError ||
      this.ordersError ||
      this.refreshError;

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
