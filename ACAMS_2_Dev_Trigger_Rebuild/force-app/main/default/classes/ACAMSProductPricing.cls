@RestResource(UrlMapping='/api/product/pricing/membership')
global with sharing class ACAMSProductPricing {

    @HttpPost
    global static ProductPricingResponse getProductPricing(Id productId, String currencyCode) {
        Decimal nonMemberPrice = null;
        Decimal memberPrice = null;

        List<ccrz__E_PriceList__c> priceListList = [
                SELECT
                        Id,
                        Name
                FROM
                        ccrz__E_PriceList__c
                WHERE
                        ccrz__CurrencyISOCode__c = :currencyCode
                AND
                        (
                            Name LIKE '%Private/Non-Member%'
                        OR
                            Name LIKE '%Private/Member%'
                        )
        ];

        List<Id> priceListIds = new List<Id>();
        for (ccrz__E_PriceList__c priceList : priceListList) {
            priceListIds.add(priceList.Id);
        }

        List<ccrz__E_PriceListItem__c> priceListItemList = [
                SELECT
                        Id,
                        ccrz__Pricelist__r.Name,
                        ccrz__Price__c
                FROM
                        ccrz__E_PriceListItem__c
                WHERE
                        ccrz__StartDate__c <= :Date.today()
                AND
                        ccrz__EndDate__c >= :Date.today()
                AND
                        ccrz__Product__c = :productId
                AND
                        ccrz__Pricelist__c IN :priceListIds
        ];

          for (ccrz__E_PriceListItem__c priceListItem : priceListItemList) {
                if (priceListItem.ccrz__Pricelist__r.Name.contains('Private/Non-Member')) {
                    if (nonMemberPrice == null) {
                        nonMemberPrice = priceListItem.ccrz__Price__c;
                    } else {
                        if (priceListItem.ccrz__Price__c < nonMemberPrice) {
                            nonMemberPrice = priceListItem.ccrz__Price__c;
                        }
                    }
                } else if (priceListItem.ccrz__Pricelist__r.Name.contains('Private/Member')) {
                    if (memberPrice == null) {
                        memberPrice = priceListItem.ccrz__Price__c;
                    } else {
                        if (priceListItem.ccrz__Price__c < memberPrice) {
                            memberPrice = priceListItem.ccrz__Price__c;
                        }
                    }
                }
          }

        ProductPricingResponse response = new ProductPricingResponse(nonMemberPrice, memberPrice);

        return response;
    }

    global class ProductPricingResponse {
        public String jsonResponse { get; set; }

        public ProductPricingResponse(Decimal nonMemberPrice, Decimal memberPrice) {
            jsonResponse = '{' + '\n' +
            '"Non-Member:" : ' + nonMemberPrice + ',' + '\n' +
            '"Member" : ' + memberPrice + '\n' +
                    '}';
        }
    }
}