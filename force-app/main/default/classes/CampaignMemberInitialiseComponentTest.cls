@isTest
public class CampaignMemberInitialiseComponentTest {

    @isTest static void testExecute_ReplaceStatuses() {

        Campaign cmp = new Campaign();
        cmp.Name = 'MoveData.io';
        insert cmp;

        CampaignMemberStatus record = new CampaignMemberStatus();
        record.Label = 'Lead';
        record.CampaignId = cmp.Id;
        record.IsDefault = true;
        record.SortOrder = 10;
        record.HasResponded = false;
        insert record;

        CampaignMemberStatusConfig configItem1 = new CampaignMemberStatusConfig();
        configItem1.Label = 'Lead';
        configItem1.IsDefault = true;
        configItem1.HasResponded = false;

        CampaignMemberStatusConfig configItem2 = new CampaignMemberStatusConfig();
        configItem2.Label = 'Customer';
        configItem2.IsDefault = false;
        configItem2.HasResponded = true;

        CampaignMemberInitialiseComponent.InitialiseCampaignMemberRequest request = new CampaignMemberInitialiseComponent.InitialiseCampaignMemberRequest();
        request.CampaignId = cmp.Id;
        request.ConfigList = new List<CampaignMemberStatusConfig>{ configItem1, configItem2 };

        List<CampaignMemberInitialiseComponent.InitialiseCampaignMemberResponse> responseList = CampaignMemberInitialiseComponent.process(new List<CampaignMemberInitialiseComponent.InitialiseCampaignMemberRequest>{ request });

        List<CampaignMemberStatus> lst = [SELECT Id, CampaignId, Label, IsDefault, HasResponded, SortOrder FROM CampaignMemberStatus WHERE CampaignId = :request.CampaignId ORDER BY SortOrder];
        System.assertEquals(2, lst.size());

        System.assertEquals(1, responseList.size());
        System.assertEquals(false, responseList[0].Cached);

        // ------

        responseList = CampaignMemberInitialiseComponent.process(new List<CampaignMemberInitialiseComponent.InitialiseCampaignMemberRequest>{ request });

        lst = [SELECT Id, CampaignId, Label, IsDefault, HasResponded, SortOrder FROM CampaignMemberStatus WHERE CampaignId = :request.CampaignId ORDER BY SortOrder];
        System.assertEquals(2, lst.size());

        System.assertEquals(1, responseList.size());
        System.assertEquals(true, responseList[0].Cached);

    }
}