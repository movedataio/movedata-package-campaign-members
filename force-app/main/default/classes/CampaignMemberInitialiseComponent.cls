public class CampaignMemberInitialiseComponent {

    public static final Integer SORT_ORDER_BASE  = 8811;
    public static final String ERROR_MESSAGE_EXISTING_SORT_ORDER = 'A Campaign Member status already a specified sort order.  Please specify a different sort order to create this Campaign Member status.';

    public static final List<Id> initialisationCache = new List<Id>();

    public class FlowComponentException extends Exception {}

    public class ExtensionMalformedCallException extends Exception {}

    public class InitialiseCampaignMemberRequest {

        public InitialiseCampaignMemberRequest() {
            this.ConfigList = new List<CampaignMemberStatusConfig>();
            this.LogList = new List<movedata.MoveDataLogEntry>();
            this.DeleteOtherCampaignMemberStatuses = false;
            this.ContinueOnError = false;
        }

        @InvocableVariable(label='Campaign Id' required=true)
        public Id CampaignId;

        @InvocableVariable(label='Campaign Member Status Collection' required=true)
        public List<CampaignMemberStatusConfig> ConfigList;

        @InvocableVariable(label='Delete Other Campaign Member Statuses' required=false)
        public Boolean DeleteOtherCampaignMemberStatuses;

        @InvocableVariable(label='Continue on Error' required=false)
        public Boolean ContinueOnError;

        /**
        * @description The list of log entries to append the entry to.
        */
        @InvocableVariable(label='List of Log Entries')
        public List<movedata.MoveDataLogEntry> LogList;

    }

    public class InitialiseCampaignMemberResponse {

        public InitialiseCampaignMemberResponse(List<movedata.MoveDataLogEntry> logList, Boolean cached) {
            this.Cached = cached;
            this.LogList = (logList == null) ? new List<movedata.MoveDataLogEntry>() : logList;

            if (cached == true) {
                movedata.MoveDataLogEntry logEntry = new movedata.MoveDataLogEntry();
                logEntry.Message = 'Initialise Campaign Members';
                logEntry.Detail = 'cached';
                this.LogList.add(logEntry);
            }

            // ------------------------------

            // Append a JSON log entry to the response
            List<Map<String, Object>> objectList = new List<Map<String, Object>>();
            for (movedata.MoveDataLogEntry item : this.LogList) {
                objectList.add(new Map<String, Object> {
                    'message' => item.Message,
                    'detail' => item.Detail
                });
            }

            this.LogJson = JSON.serialize(objectList);
        }

        @InvocableVariable(label='Cached' description='Identifies if the campaign has previous been initialised in the current transaction')
        public Boolean Cached;

        /**
        * @description The list of log entries to append the entry to.
        */
        @InvocableVariable(label='List of Log Entries' required=true)
        public List<movedata.MoveDataLogEntry> LogList;

        /**
        * @description A JSON-encoded version of the flow's log entries.
        */
        @InvocableVariable(label='Json Output of Log Entries')
        public String LogJson;

    }

    @InvocableMethod
    public static List<InitialiseCampaignMemberResponse> process(List<InitialiseCampaignMemberRequest> requestList) {
        List<InitialiseCampaignMemberResponse> responseList = new List<InitialiseCampaignMemberResponse>();

        List<CampaignMemberStatus> updateStatusList = new List<CampaignMemberStatus>();
        List<CampaignMemberStatus> deleteStatusList = new List<CampaignMemberStatus>();

        Boolean continueOnError = (requestList.size() > 0) ? requestList[0].ContinueOnError : false;
        Boolean deleteStatus = (requestList.size() > 0) ? requestList[0].DeleteOtherCampaignMemberStatuses : false;

        // ------------------------------------------------------------------------------------------
        // Iterate the requests

        for (InitialiseCampaignMemberRequest request : requestList) {
            if (request.LogList == null) request.LogList = new List<movedata.MoveDataLogEntry>();

            if (CampaignMemberInitialiseComponent.initialisationCache.contains(request.CampaignId) == true) { responseList.add(new InitialiseCampaignMemberResponse(request.LogList, true)); continue; }
            if (request.ConfigList == null) throw new ExtensionMalformedCallException('You must pass a list of Campaign Member Statuses.');

            // ------------------------------------------------------------------------------------------

            // Do we need to create the sort order?
            Boolean createSortOrder = false;
            for (CampaignMemberStatusConfig configItem : request.ConfigList) { 
                if (configItem.SortOrder == null) { createSortOrder = true; break; }
            }
            
            // Yes - Create sort order using SORT_ORDER_BASE and increment by 10.
            if (createSortOrder == true) {
                Integer i = 0;
                for (CampaignMemberStatusConfig configItem : request.ConfigList) { 
                    configItem.SortOrder = SORT_ORDER_BASE + (i * 10);
                    i++;
                }
            }

            // ------------------------------------------------------------------------------------------
            // Identify existing and orphaned status records

            List<CampaignMemberStatus> existingList = new List<CampaignMemberStatus>();

            // Get existing Campaign Member Statuses
            List<CampaignMemberStatus> lst = [SELECT Id, CampaignId, Label, IsDefault, HasResponded, SortOrder FROM CampaignMemberStatus WHERE CampaignId = :request.CampaignId];

            for (CampaignMemberStatus item : lst) {
                Boolean processed = false;

                // See if we have an existing Campaign Status Member
                for (CampaignMemberStatusConfig configItem : request.ConfigList) { 
                    // System.Debug('CampaignMemberStatus item: ' + item);
                    if (item.Label == configItem.Label) { configItem.Record = item; processed = true; }
                }

                if (processed == false) {
                    // No match - Add to delete list; evaluated later on.
                    deleteStatusList.add(item);
                }
                else {
                    // Match - Add to existing list.
                    existingList.add(item);
                }
            }
            System.Debug('deleteStatusList: ' + deleteStatusList);

            // ------------------------------------------------------------------------------------------
            // Create the Campaign Member Status records for addition. 

            for (CampaignMemberStatusConfig configItem : request.ConfigList) {
                // Ignore any existing entries.
                if (configItem.Record != null) continue;
        
                // Populate a Campaign Member Status record
                CampaignMemberStatus record = new CampaignMemberStatus();
                record.Label = configItem.Label;
                record.CampaignId = request.CampaignId;
                record.IsDefault = configItem.IsDefault;
                record.SortOrder = configItem.SortOrder;
                record.HasResponded = configItem.HasResponded;

                // Add to the Upsert list for addition.
                updateStatusList.add(record);
            }

            // Create a log entry.
            movedata.MoveDataLogEntry logEntry = new movedata.MoveDataLogEntry();
            logEntry.Message = 'Initialise Campaign Members';
            logEntry.Detail = JSON.serializePretty(new Map<String, Object> {
                'updateList' => updateStatusList,
                'deleteList' => deleteStatusList
            });

            // Append a structure MoveData Log Entry to the response
            request.LogList.add(logEntry);

            // Mark as initialise in Cache and set response.
            CampaignMemberInitialiseComponent.initialisationCache.add(request.CampaignId);
            responseList.add(new InitialiseCampaignMemberResponse(request.LogList, false));
        }

        // ------------------------------------------------------------------------------------------
        // Commit Handler

        try {
            // Execute Upsert for New Campaign Member Statuses
            try {
                System.Debug('updateStatusList: ' + updateStatusList);
                if (updateStatusList.size() > 0) upsert updateStatusList;
            }
            catch (DmlException ex) {
                // If a duplicate sort order exists, throw a nuanced error message.
                if (ex.getMessage().IndexOf('DUPLICATE_VALUE') > -1) { throw new FlowComponentException(CampaignMemberInitialiseComponent.ERROR_MESSAGE_EXISTING_SORT_ORDER); }
                else { throw ex; }
            }

            // -------------------------

            System.Debug('deleteStatus: ' + deleteStatus);
            System.Debug('deleteStatusList: ' + deleteStatusList);

            // If directed to delete any existing, unidentified statuses, perform delete.
            // - Suppress any Delete Failures as not critical enough to fail complete process.
            if (deleteStatus == true) {
                try { if (deleteStatusList.size() > 0) delete deleteStatusList; }
                catch (DmlException ex) { System.Debug('Could not delete existing record.  Error suppressed.'); }
            }
        }
        catch (Exception ex) {
            // If continue on error is flagged, suppress exception; otherwise, allow to bubble up.
            if (continueOnError) { System.Debug('Exception: ' + ex); }
            else { throw ex; }
        }

        return responseList;
   }
}