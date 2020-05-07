public with sharing class ACAMSAccountDAO {

    public static List<Account> getAccountsFromId(Set<Id> idSet) {
        List<Account> accounts = [
                SELECT
                        Id,
                        ccrz__E_AccountGroup__c,
                        PersonEmail
                FROM
                        Account
                WHERE
                        Id IN :idSet
                AND
                        IsPersonAccount = TRUE
        ];

        return accounts;
    }

    public static Contact getContact(Id contactId) {
        Contact contact;
        List<Contact> contacts = [
                SELECT
                        Id,
                        FirstName,
                        LastName,
                        AccountId,
                        Email
                FROM
                        Contact
                WHERE
                        Id = :contactId
        ];
        if (!contacts.isEmpty()) {
            contact = contacts.get(0);
        }

        return contact;
    }

    public static List<Account> getAccountsFromAccountAddressBook(Set<Id> ids) {
        List<Account> accounts = [
                SELECT
                        Id
                FROM
                        Account
                WHERE
                        Id IN :ids
        ];

        return accounts;
    }

    public static List<ccrz__E_ContactAddr__c> getContactAddressesFromAccountAddressBook(Set<Id> ids) {
        List<ccrz__E_ContactAddr__c> contactAddrs = [
                SELECT
                        Id,
                        ccrz__City__c,
                        ccrz__State__c,
                        ccrz__Country__c,
                        ccrz__PostalCode__c,
                        ccrz__CountryISOCode__c,
                        ccrz__StateISOCode__c,
                        ccrz__AddressFirstline__c,
                        ccrz__AddressSecondline__c,
                        ccrz__AddressThirdline__c
                FROM
                        ccrz__E_ContactAddr__c
                WHERE
                        Id IN :ids
        ];

        return contactAddrs;
    }
}