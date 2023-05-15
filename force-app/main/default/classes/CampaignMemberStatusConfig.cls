/**
* @author James Kent (jkent@movedata.io)
* @date 2023
* @description Configuration entry for Campaign Member Status
*/
public with sharing class CampaignMemberStatusConfig {

    /**
    * @description The Label for the Campaign Status
    */
    @AuraEnabled public String Label;

    /**
    * @description The Sort Order for the campaign Status
    */
    @AuraEnabled public Integer SortOrder;

    /**
    * @description Is the default status or not
    */
    @AuraEnabled public Boolean IsDefault;

    /**
    * @description Mark as Has Responded or not
    */
    @AuraEnabled public Boolean HasResponded;

    /**
    * @description Holds a reference to the Campaign Member Status SObject
    */
    public CampaignMemberStatus Record;

}