@isTest
public class CampaignMemberCreateComponentTest {

    @isTest static void testExecute_UpgradeExistingMember() {

        Contact con = new Contact();
        con.FirstName = 'James';
        con.LastName = 'Kent';
        insert con;

        Campaign cmp = new Campaign();
        cmp.Name = 'MoveData.io';
        insert cmp;

        CampaignMember entry = new CampaignMember();
        entry.CampaignId = cmp.Id;
        entry.ContactId = con.Id;
        entry.Status = 'Sent';
        insert entry;

        CampaignMemberStatusConfig configItem1 = new CampaignMemberStatusConfig();
        configItem1.Label = 'Responded';
        configItem1.IsDefault = false;
        configItem1.HasResponded = true;

        CampaignMemberStatusConfig configItem2 = new CampaignMemberStatusConfig();
        configItem2.Label = 'Sent';
        configItem2.IsDefault = true;
        configItem2.HasResponded = false;

        CampaignMemberCreateComponent.CreateCampaignMemberRequest request = new CampaignMemberCreateComponent.CreateCampaignMemberRequest();
        request.ContactId = con.Id;
        request.CampaignIdList = new List<Id> { cmp.Id };
        request.ConfigList = new List<CampaignMemberStatusConfig>{ configItem1, configItem2 };
        request.Value = 'Responded';

        CampaignMemberCreateComponent.process(new List<CampaignMemberCreateComponent.CreateCampaignMemberRequest>{ request });

        List<CampaignMember> lst = [SELECT Id, CampaignId, ContactId, Status FROM CampaignMember];

        System.assertEquals(1, lst.size());
        System.assertEquals(cmp.Id, lst[0].CampaignId);
        System.assertEquals(con.Id, lst[0].ContactId);
        System.assertEquals(request.Value, lst[0].Status);
    }

}
