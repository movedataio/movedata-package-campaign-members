global class CampaignMemberCreateComponent {

    global class FlowComponentException extends Exception {}

    global class CreateCampaignMemberRequest {

        public CreateCampaignMemberRequest() {
            this.ConfigList = new List<CampaignMemberStatusConfig>();
            this.CampaignIdList = new List<Id>();
        }

        @InvocableVariable(label='Campaign Member Fieldset')
        global String FieldsetName;

        @InvocableVariable(label='Contact ID')
        global Id ContactId;

        @InvocableVariable(label='Campaign ID List' description='All Campaigns to be assigned to the Individual' required=true)
        global List<Id> CampaignIdList;

        @InvocableVariable(label='Campaign Member Status List' description='A list of the campaign member statuses.  Will not set a lower status over a higher status.' required=true)
        global List<CampaignMemberStatusConfig> ConfigList;

        @InvocableVariable(label='Value' required=true)
        global String Value;

        /**
        * @description The list of log entries to append the entry to.
        */
        @InvocableVariable(label='List of Log Entries')
        global List<movedata.MoveDataLogEntry> LogList;

    }

    global class CreateCampaignMemberResponse {

        global CreateCampaignMemberResponse() {
            this.Success = true;
        }

        @InvocableVariable(label='Success')
        global Boolean Success;

        /**
        * @description The list of log entries to append the entry to.
        */
        @InvocableVariable(label='List of Log Entries' required=true)
        global List<movedata.MoveDataLogEntry> LogList;

        /**
        * @description A JSON-encoded version of the flow's log entries.
        */
        @InvocableVariable(label='Json Output of Log Entries')
        global String LogJson;

        /**
        * @description A JSON-encoded version of the flow's log entries.
        */
        @InvocableVariable(label='Campaign Member Record')
        global CampaignMember Record;



    }

    public static Integer getValueIndex(List<CampaignMemberStatusConfig> configList, String value) {
        if (configList != null) {
            for (Integer i = 0; i < configList.size(); i++) {
                if (configList[i].Label == value) return i;
            }
        }

        return -1;
    }

    @InvocableMethod
    global static List<CreateCampaignMemberResponse> process(List<CreateCampaignMemberRequest> requestList) {
        List<CreateCampaignMemberResponse> responseList = new List<CreateCampaignMemberResponse>();
        List<CampaignMember> changesList = new List<CampaignMember>();

        for (CreateCampaignMemberRequest request : requestList) {
            CreateCampaignMemberResponse response = new CreateCampaignMemberResponse();
            response.LogList = (request.LogList == null) ? new List<movedata.MoveDataLogEntry>() : request.LogList;

            if (request.ContactId != null) {
              if (request.CampaignIdList == null || request.CampaignIdList.size() == 0) throw new FlowComponentException('Campaign Id List is not present or correctly populated.');
              if (request.Value == null) throw new FlowComponentException('Value is not present.');

              Integer valueIndex = CampaignMemberCreateComponent.getValueIndex(request.ConfigList, request.Value);
              if (valueIndex == -1) throw new FlowComponentException('Value must be present in the Value Heirarchy.');

              // ---------------------------

              List<String> campaignIdList = new List<String>();
              for (String campaignId : request.CampaignIdList) {
                campaignIdList.add('\'' + campaignId + '\'');
              }

              List<String> soqlList = new List<String>{
                'SELECT',
                String.join(CampaignMemberCreateComponent.GetFields(request), ', '),
                //'FROM CampaignMember WHERE CampaignId IN :request.CampaignIdList AND ContactId = :request.ContactId'
                'FROM CampaignMember',
                'WHERE',
                'CampaignId IN (',
                String.join(campaignIdList, ', '),
                ')',
                'AND',
                'ContactId = ',
                '\'' + request.ContactId + '\''
              };
                
              // Execute soql query
              String soqlQuery = String.join(soqlList, ' ');
              System.Debug('soqlQuery: ' + soqlQuery);

              List<SObject> objectQueryList = Database.query(soqlQuery);
              List<CampaignMember> queryList = (objectQueryList.size() == 0) ? new List<CampaignMember>() : (List<CampaignMember>)objectQueryList;

              // List<CampaignMember> queryList = [SELECT Id, CampaignId, ContactId, Status FROM CampaignMember WHERE CampaignId IN :request.CampaignIdList AND ContactId = :request.ContactId];

              // ---------------------------

              for (Id campaignId : request.CampaignIdList) {
                  Boolean processed = false;

                  for (CampaignMember entry : queryList) {
                      if (entry.CampaignId == campaignId && entry.ContactId == request.ContactId) {
                          processed = true;
                          response.Record = entry;

                          Integer currentValueIndex = CampaignMemberCreateComponent.getValueIndex(request.ConfigList, entry.Status);
                          if (valueIndex == currentValueIndex) {
                              processed = true;
                              continue;                            
                          }
                          if (currentValueIndex == -1 || currentValueIndex > valueIndex) {
                              entry.Status = request.Value;
                              changesList.add(entry);
                              processed = true;
                              continue;
                          }
                      }
                  }

                  if (processed == false) {
                      CampaignMember entry = new CampaignMember();
                      entry.CampaignId = campaignId;
                      entry.ContactId = request.ContactId;
                      entry.Status = request.Value;
                      changesList.add(entry);

                      response.Record = entry;

                      // ------------------------------

                      // Create a log entry.
                      movedata.MoveDataLogEntry logEntry = new movedata.MoveDataLogEntry();
                      logEntry.Message = 'Upsert Campaign Member';
                      logEntry.Detail = JSON.serializePretty(entry);

                      // Append a structure MoveData Log Entry to the response
                      response.LogList.add(logEntry);

                      // ------------------------------
                  
                  }
              }

              // ------------------------------

              // Append a JSON log entry to the response
              List<Map<String, Object>> objectList = new List<Map<String, Object>>();
              for (movedata.MoveDataLogEntry item : response.LogList) {
                  objectList.add(new Map<String, Object>{
                      'message' => item.Message,
                      'detail' => item.Detail
                  });
              }

              response.LogJson = JSON.serialize(objectList);
              System.Debug('LogJson: ' + response.LogJson);

              // ------------------------------
            }

            // Append the response
            responseList.add(response);
        }

        // System.Debug('changesList: ' + changesList);
        if (changesList.size() > 0) upsert changesList;

        return responseList;
   }

   public static List<String> GetFields(CreateCampaignMemberRequest request) {
        Set<String> fieldSet = new Set<String>{ 'Id', 'CampaignId', 'ContactId', 'Status' };

        if (request.FieldsetName != null) {
            // Get a list of fieldset for the requested object type
            Schema.DescribeSObjectResult objectMetadata = CampaignMember.SObjectType.getDescribe();
            Map<String, Schema.FieldSet> fieldSetMap = objectMetadata.FieldSets.getMap();
            
            if (fieldSetMap.containsKey(request.FieldsetName) == true) {
                List<Schema.FieldSetMember> fieldSetMemberList = fieldSetMap.get(request.FieldsetName).getFields();
                for (Schema.FieldSetMember fld : fieldSetMemberList) {
                    fieldSet.add(fld.getFieldPath());
                }
            }
        }

        List<String> fieldList = new List<String>(fieldSet);
        System.Debug(fieldList);

        return fieldList;
    }
}