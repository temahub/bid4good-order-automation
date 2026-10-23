public with sharing class OrderEmailService {
    private static final String TEMPLATE_DEVELOPER_NAME = 'Bid4Good_Order_Email';

    @AuraEnabled
    public static void sendOrderEmail(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('An Order record ID is required.');
        }

        // Verify that the current user can access this Order__c.
        List<Order__c> accessibleOrders = [
            SELECT Id
            FROM Order__c
            WHERE Id = :orderId
            WITH USER_MODE
            LIMIT 1
        ];

        if (accessibleOrders.isEmpty()) {
            throw new AuraHandledException('The Order does not exist or is not accessible.');
        }

        String recipientEmail = UserInfo.getUserEmail();

        if (String.isBlank(recipientEmail)) {
            throw new AuraHandledException('The current user does not have an email address.');
        }

        List<EmailTemplate> templates = [
            SELECT Id, TemplateType
            FROM EmailTemplate
            WHERE DeveloperName = :TEMPLATE_DEVELOPER_NAME
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (templates.isEmpty()) {
            throw new AuraHandledException('The Bid4Good Order Email template was not found.');
        }

        if (templates[0].TemplateType != 'visualforce') {
            throw new AuraHandledException('The configured email template must be a Visualforce template.');
        }

        Messaging.SingleEmailMessage renderedMessage;

        try {
            renderedMessage = Messaging.renderStoredEmailTemplate(
                String.valueOf(templates[0].Id),
                String.valueOf(UserInfo.getUserId()),
                String.valueOf(orderId)
            );
        } catch (Exception e) {
            throw new AuraHandledException('The order email template could not be rendered.');
        }

        if (
            String.isBlank(renderedMessage.getSubject()) ||
            (String.isBlank(renderedMessage.getHtmlBody()) && String.isBlank(renderedMessage.getPlainTextBody()))
        ) {
            throw new AuraHandledException('The rendered email template does not contain a subject or body.');
        }

        // Send the rendered content as a new message.
        // The recipient is an email address, not a User TargetObjectId.
        Messaging.SingleEmailMessage outgoingEmail = new Messaging.SingleEmailMessage();

        outgoingEmail.setToAddresses(new List<String>{ recipientEmail });

        List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];

        if (!owea.isEmpty()) {
            outgoingEmail.setOrgWideEmailAddressId(owea[0].Id);
        }

        outgoingEmail.setSubject(renderedMessage.getSubject());

        if (String.isNotBlank(renderedMessage.getHtmlBody())) {
            outgoingEmail.setHtmlBody(renderedMessage.getHtmlBody());
        }

        if (String.isNotBlank(renderedMessage.getPlainTextBody())) {
            outgoingEmail.setPlainTextBody(renderedMessage.getPlainTextBody());
        }

        outgoingEmail.setSaveAsActivity(false);
        outgoingEmail.setUseSignature(false);

        Messaging.SendEmailResult[] results = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ outgoingEmail },
            false
        );

        if (results.isEmpty() || !results[0].isSuccess()) {
            String errorMessage = 'Salesforce could not queue the email.';

            if (!results.isEmpty()) {
                Messaging.SendEmailError[] errors = results[0].getErrors();

                if (errors != null && !errors.isEmpty()) {
                    errorMessage = errors[0].getMessage();
                }
            }

            throw new AuraHandledException(errorMessage);
        }
    }
}
