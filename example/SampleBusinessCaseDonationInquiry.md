# Create Business Case For Donation Inquiry Type
```
 URL:           https://api.ebill.billte.ch/swp/v1/billers/business-cases
 Method :        POST
 Auth required : YES(Bearer token)
```

**In this example biller (Fitness Centre XYZ) is sending a donation inquiry to recipient (Test Notify2)**

## Request Parameters

| Parameter 	| Type 	| Required 	| Description 	|
|---	|---	|---	|---	|
| billRecipient 	| Object 	| true 	| In bill recipient<br>```{ emailAddress:String},{name:String}``` 	|
| biller 	| Object 	| true 	| Biller object contains   <br>     ``` {billerPid:String,```<br>    ```"legalName":"String",```<br>    ```"postalAddress":Object``` <br>```}``` <br><br>Postal Address Contains<br>```{buildingNumber:String,"city":"String"},"countryCode":"String","postalCode":"String","street":"String"}``` 	|
| businessCaseType 	| String 	| true 	| Use business case value ```DonationInquiry``` 	|
| dueDate 	| String 	| false 	| At time of submission, cannot be set to more than 3 years in the future (1095 days).<br>At time of submission, cannot be older than 90 days. 	|
| fileIdentifier 	| String 	| true 	| Name for the Business Case PDF file 	|
| payableAmountCanBeModified 	| Boolean 	| true 	| Must be set to true for donation inquiries to allow the recipient to select or enter a donation amount 	|
| referenceNumber 	| String 	| false 	| Must be unique for the invoice issuer. 	|
| singlePayment 	| Object 	| true 	| Information about the payment<br><br>```{"paymentInformation":Object}```<br><br>**In payment information object contains properties**:<br><br>    :**properties**:<br><br>1.      ```accountandReference```<br>         type:Object<br>         Required:true<br>2      ```amount```<br>         type:Object<br>         Required:true<br>         Definition:<br>                      For donation inquiries, the value must be an empty string ("") when proposedDonationAmounts is specified<br>3     ```dueDate```<br>         type:String<br>         Required:true<br>         Definition:            <br>            At time of submission, cannot be set to more than 3 years in the future (1095 days).<br>            At time of submission, cannot be older than 90 days.<br><br>4     ```payableAmountCanBeModified```<br>         type:Boolean<br>         Required:true<br>           Definition:<br>           Must be set to true for donation inquiries to allow the recipient to select one of the proposed amounts or enter a free amount<br><br><br><br>       :**accountandReference contains properties**:<br><br>               **properties**:<br> <br>1.1               ```esr```<br>                   type:Object<br> <br><br>1.2              ```generic```<br>                  type:Object<br><br>                **Requires any object esr or generic**<br><br>              **For Esr:->** ```In case invoicing is performed with the ESR format (orange inpayment slip),```<br>              ```information from this element is used. The corresponding specifications apply,```<br>              ```especially regarding the content of the reference number```<br>                ``` ESR reference number (including check digit)```<br><br><br><br>**For Generic:->**    In case invoicing is performed with the IBAN format, this element is used for the<br>information. The corresponding specifications apply.<br><br><br>                                     **esr contains properties**:<br><br>                  1.1.1    ```esrParticipantNumber```     <br>                                type:String<br>                                  Required:true<br>                                Definition:`<br><br>                                          ```Credit account of the invoice issuer (ESR-participant number). 9 characters,```<br>                                           ```numeric value, unhyphenated.```<br>```Composition: VV999999P<br>- VV = ESR code (01 for ESR in CHF or 03 for ESR in EUR)<br>- 999999 = serial number: if number has less than 6 digits, it must be filled with<br>zeros on the left side; must be bigger than 000000.<br>- P = check digit according to Modulus 10 recursive.```<br><br><br>```Example: 010001628<br>Must be matching with a credit account that is specified in the infrastructure in the<br>master data of the invoice issuer, otherwise the business case will be denied.<br>If ESR code = 01, the currency code must be CHF.<br>If ESR code = 03, the currency code must be EUR.```<br><br><br><br><br><br>       <br>1.1.2 ```referenceStructured```<br>                              type:String<br>                              Required:true<br>                            Definition:<br><br>```ESR reference number (including check digit)```<br><br><br>**generic contains properties**<br><br>1.2.1 ```iban```<br>                type:String<br>                  Required:true<br>               Definition:<br>```Credit account of the invoice issuer (IBAN or QR-IBAN). See also ISO 13616-1.```<br>```The usage of IBAN or QR-IBAN is only permitted with country codes CH or LI and```<br>```21 alphanumeric characters```<br><br>```Example: CH9300762011623852957```<br>                 ```LI21088100002324013AA```<br><br>```Must contain country code CH or LI, otherwise the business case will be denied.```<br>```Must be matching with a credit account that is specified in the infrastructure in the```<br>```master data of the invoice issuer, otherwise the business case will be denied.```<br><br>1.2.3 ```referenceStructured```<br>      type:String<br>        Required:false<br>    Definition:<br>```Reference number, structured payment reference.```<br>```Note: the reference is either a QR reference, creditor reference (ISO 11649) or anIPI reference.```<br>```QR Reference: 27 characters, numerical; check digit computation with Modulus 10recursive (27th position of the reference).Creditor Reference (ISO 11649): up to 25 characters, alphanumeric.IPI Reference: 20 characters, alphanumeric; check digit computation with Modulus97-10 (ISO 7064) (Note: the IPI receipt was eliminated by 31.03.2020)When using QR-IBAN, this element must be filled with the QR Reference.```<br>```When using IBAN and referenceType SCOR, this element must be filled with the```<br>```Creditor Reference.```<br>```When using IBAN and referenceType IPI, this element must be filled with the IPI```<br>```Reference.```<br>```When using IBAN and referenceType NON, this element is not permitted to be```<br>```filled.```<br><br>1.2.4 ```referenceType```<br>        type:String<br>         Required:true<br>      Definition:<br>```Reference type of the structured reference.```<br>```Following values are permitted:```<br>```QRR - QR Reference```<br>```SCOR - Creditor Reference (ISO 11649)```<br>```NON - without reference```<br>```IPI - IPI Reference (Note: the IPI receipt was eliminated by 31.03.2020)```<br>```When using the QR-IBAN, the code QRR must be included.```<br>```When using the IBAN, either the code SCOR, IPI or NON must be included.```<br><br>1.2.5 ```referenceUnstructured```<br>     type:String<br>       Required:false<br>       Definition:Unstructured message<br><br><br><br>2 :**amount contains properties**:<br>         <br>        **properties**:<br><br>       2.1 ```currency```:<br>                type:String<br>                Definition:<br> <br>                 Currency code according to ISO 4217<br>                 When using QR-IBAN or ESR-participant number, only CHF and EUR are<br>                 allowed.<br><br>    <br>         2.2 ```value```<br>                  type:String<br>                  Definition:<br>                       <br>                    For donation inquiries, the value must be an empty string ("") when proposedDonationAmounts is specified<br>                  <br>              <br><br><br><br><br><br><br><br> <br><br><br> 	|
| totalAmount 	| Object 	| true 	| ```Total amount``` object contains properties:<br>   <br><br>        1 ```currency```:<br>                type:String<br>                Definition:<br> <br>                 Currency code according to ISO 4217<br>                 When using QR-IBAN or ESR-participant number, only CHF and EUR are<br>                 allowed.<br><br>    <br>         2 ```value```:<br>                  type:String<br>                  Definition:<br>                       <br>                    For donation inquiries, the value must be an empty string ("") when proposedDonationAmounts is specified 	|
| proposedDonationAmounts 	| Object 	| true 	| Contains an array of proposed donation amounts that the recipient can choose from<br><br>```{"proposedDonationAmount":Array}```<br><br>Each amount in the array contains:<br>- currencyCode: String (required)<br>- value: String (required)<br><br>The array must contain at least 2 and at most 5 amounts 	|
| donationPurposes 	| Object 	| false 	| Optional list of donation purposes<br><br>```{"donationPurpose":Array}```<br><br>Each purpose in the array contains:<br>- externalDonationPurposeId: String (required)<br>- label: String (required)<br><br>The array must contain at least 1 and at most 10 purposes 	|
| referencedBill 	| Object 	| false 	| Reference to an existing bill<br><br>```{"referenceNumber":String}``` 	|

## Sample Request
```json
{
    "billRecipient": {
        "name": "Test Notify2",
        "billRecipientId": "41012124671750544",
        "address": {
            "structuredAddress": {
                "street": "soodmattenstrasse",
                "buildingNumber": "34/43",
                "postalCode": "3456",
                "city": "CH",
                "countryCode": "CH"
            }
        }
    },
    "biller": {
        "billerPid": "41140062400857359",
        "legalName": "Fitness Centre XYZ",
        "postalAddress": {
            "street": "soodmattenstrasse",
            "buildingNumber": "34/43",
            "postalCode": "3456",
            "city": "CH",
            "countryCode": "CH"
        }
    },
    "businessCaseDate": "2025-01-25T09:53:31.814795Z",
    "businessCaseType": "DonationInquiry",
    "contentType": "PDF",
    "fileIdentifier": "invoice.pdf",
    "totalAmount": {
        "currencyCode": "CHF",
        "value": ""
    },
    "proposedDonationAmounts": {
        "proposedDonationAmount": [
            {
                "currencyCode": "CHF",
                "value": "10.00"
            },
            {
                "currencyCode": "CHF",
                "value": "15.00"
            }
        ]
    },
    "donationPurposes": {
        "donationPurpose": [
            {
                "externalDonationPurposeId": "1231",
                "label": "donation"
            }
        ]
    },
    "referencedBill": {
        "referenceNumber": "101403020210915152001795560"
    },
    "singlePayment": {
        "paymentInformation": {
            "payableAmountCanBeModified": true,
            "accountAndReference": {
                "generic": {
                    "iban": "CH3389144487682315978",
                    "referenceType": "NON"
                }
            },
            "dueDate": "2025-03-25T00:00:00.000Z",
            "amount": {
                "currencyCode": "CHF",
                "value": ""
            }
        },
        "paymentMode": "EBILL"
    },
    "content": ""
}
```
## Response

***Success Response***

HTTP Status Codes for success -> 200
```json
{
    "type": "DonationInquiry",
    "id": "BCID363F813AF14644CEB3E9E4DE8474E6E3",
    "referenceNumber": "DonationInquiry2025-01-25T09:53:31.814795Z",
    "businessCaseDate": "2025-01-25",
    "status": "OPEN",
    "totalAmount": {
        "value": "",
        "currencyCode": "CHF"
    },
    "billerPid": "41140062400857359"
}
```
***Failed Response***

HTTP Status Codes for success -> 400
 For Bad Request:
```json
{
    "error": {
        "error": "error message that missing in your request"
    }
}
``` 