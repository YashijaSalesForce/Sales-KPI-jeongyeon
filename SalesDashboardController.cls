public with sharing class SalesDashboardController {

    // Wrapper 클래스들은 변경 없습니다.
    public class DashboardData {
        @AuraEnabled public GoalData goalInfo { get; set; }
        @AuraEnabled public List<FunnelStep> funnelSteps { get; set; }
    }
    public class GoalData {
        @AuraEnabled public Integer goalCount { get; set; }
        @AuraEnabled public Integer actualCount { get; set; }
        @AuraEnabled public Double achievementRate { get; set; }
    }
    public class FunnelStep {
        @AuraEnabled public String stageName { get; set; }
        @AuraEnabled public Integer oppCount { get; set; }
        @AuraEnabled public Double conversionRate { get; set; }
    }

    // 기존 대시보드 데이터 조회 메소드
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        Id currentUserId = UserInfo.getUserId();
        DashboardData response = new DashboardData();
        response.goalInfo = calculateGoalAchievement(currentUserId);
        response.funnelSteps = calculateFunnelAnalysis(currentUserId);
        return response;
    }

    // 특정 단계의 기회 목록을 가져오는 메소드
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunitiesForStage(String stageName) {
        Id currentUserId = UserInfo.getUserId();
        return [
            SELECT Id, Name, Amount, CloseDate
            FROM Opportunity
            WHERE OwnerId = :currentUserId AND StageName = :stageName AND IsClosed = false
            ORDER BY CloseDate ASC
            LIMIT 50
        ];
    }


    // --- Private Helper Methods ---

    /**
     * [수정됨] 이번 달 목표 달성률을 계산합니다.
     * Sales_Goal__c 레코드가 없으면 기본 목표를 10으로 설정합니다.
     */
    private static GoalData calculateGoalAchievement(Id userId) {
        GoalData goalData = new GoalData();
        
        // 이번 달 목표를 Sales_Goal__c 오브젝트에서 조회
        List<Sales_Goal__c> goals = [SELECT Goal_Count__c FROM Sales_Goal__c WHERE Sales_Rep__c = :userId AND Goal_Month__c = THIS_MONTH LIMIT 1];
        
        // 조회된 목표가 있으면 해당 값을 사용하고, 없으면 기본값 10으로 설정
        if (!goals.isEmpty() && goals[0].Goal_Count__c != null) {
            goalData.goalCount = Integer.valueOf(goals[0].Goal_Count__c);
        } else {
            // [수정] 데이터가 없을 경우, 테스트 및 시연을 위해 기본 목표를 10으로 설정합니다.
            goalData.goalCount = 10; 
        }
        
        // 이번 달에 성공한 기회 건수 계산
        AggregateResult[] closedWon = [SELECT COUNT(Id) cnt FROM Opportunity WHERE OwnerId = :userId AND StageName = 'Closed Won' AND CloseDate = THIS_MONTH];
        goalData.actualCount = (Integer)closedWon[0].get('cnt');
        
        // 달성률 계산
        if (goalData.goalCount > 0) {
            goalData.achievementRate = ((Double)goalData.actualCount / goalData.goalCount) * 100;
        } else {
            goalData.achievementRate = 0.0;
        }
        
        return goalData;
    }

    /**
     * 단계별 깔때기 분석 및 전환율을 계산합니다. (변경 없음)
     */
    private static List<FunnelStep> calculateFunnelAnalysis(Id userId) {
        List<String> stageOrder = new List<String>();
        for (Schema.PicklistEntry p : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (!p.getLabel().contains('Closed')) {
                stageOrder.add(p.getLabel());
            }
        }

        Map<String, Integer> currentStageCounts = new Map<String, Integer>();
        for (String stage : stageOrder) {
            currentStageCounts.put(stage, 0);
        }
        for(AggregateResult ar : [
            SELECT StageName, COUNT(Id) cnt FROM Opportunity
            WHERE OwnerId = :userId AND IsClosed = false GROUP BY StageName
        ]){
            currentStageCounts.put((String)ar.get('StageName'), (Integer)ar.get('cnt'));
        }

        Map<String, Integer> funnelCounts = new Map<String, Integer>();
        Integer cumulativeCount = 0;
        for (Integer i = stageOrder.size() - 1; i >= 0; i--) {
            String stage = stageOrder[i];
            cumulativeCount += currentStageCounts.get(stage);
            funnelCounts.put(stage, cumulativeCount);
        }
        
        List<FunnelStep> funnelSteps = new List<FunnelStep>();
        for (Integer i = 0; i < stageOrder.size(); i++) {
            String currentStage = stageOrder[i];
            
            FunnelStep step = new FunnelStep();
            step.stageName = currentStage;
            step.oppCount = currentStageCounts.get(currentStage);

            Integer currentStageReachedCount = funnelCounts.get(currentStage);

            if (i + 1 < stageOrder.size()) {
                String nextStage = stageOrder[i + 1];
                Integer nextStageReachedCount = funnelCounts.get(nextStage);

                if (currentStageReachedCount > 0) {
                    step.conversionRate = ((Double)nextStageReachedCount / currentStageReachedCount) * 100;
                } else {
                    step.conversionRate = 0.0;
                }
            } else {
                step.conversionRate = null;
            }
            funnelSteps.add(step);
        }
        return funnelSteps;
    }
}
