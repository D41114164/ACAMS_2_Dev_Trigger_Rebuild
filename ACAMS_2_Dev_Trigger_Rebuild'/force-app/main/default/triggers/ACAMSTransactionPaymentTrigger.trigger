trigger ACAMSTransactionPaymentTrigger on ccrz__E_TransactionPayment__c (before insert) {
    new ACAMSTransactionPaymentTriggerHandler().run();
}