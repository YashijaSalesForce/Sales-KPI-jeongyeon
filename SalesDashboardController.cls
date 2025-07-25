public with sharing class SalesDashboardController {
  // Wrapper 클래스들
  public class DashboardData {
    @AuraEnabled
    public GoalData goalInfo { get; set; }
    @AuraEnabled
    public List<FunnelStep> funnelSteps { get; set; }
    @AuraEnabled
    public List<SalesRep> salesReps { get; set; }
  }
  public class GoalData {
    @AuraEnabled
    public Integer goalCount { get; set; }
    @AuraEnabled
    public Integer actualCount { get; set; }
    @AuraEnabled
    public Double achievementRate { get; set; }

    // 주간 목표 관련 필드
    @AuraEnabled
    public Integer weeklyGoal { get; set; }
    @AuraEnabled
    public Integer weeklyActual { get; set; }
    @AuraEnabled
    public Double weeklyAchievementRate { get; set; }
    @AuraEnabled
    public Integer currentWeekOfMonth { get; set; }

    // 일일 평균 필요 성과
    @AuraEnabled
    public Double dailyRequiredAverage { get; set; }
    @AuraEnabled
    public Integer remainingWorkDays { get; set; }
    @AuraEnabled
    public Integer remainingGoal { get; set; }
  }
  public class FunnelStep {
    @AuraEnabled
    public String stageName { get; set; }
    @AuraEnabled
    public Integer oppCount { get; set; }
    @AuraEnabled
    public Double conversionRate { get; set; }
  }
  public class SalesRep {
    @AuraEnabled
    public Id Id { get; set; }
    @AuraEnabled
    public String Name { get; set; }
    @AuraEnabled
    public GoalData goalInfo { get; set; }
    @AuraEnabled
    public List<FunnelStep> funnelSteps { get; set; }
  }

  // 대시보드 데이터 조회 메소드 (전체 + 영업사원별)
  @AuraEnabled(cacheable=true)
  public static DashboardData getDashboardData() {
    Id currentUserId = UserInfo.getUserId();
    DashboardData response = new DashboardData();

    // 전체 데이터 (현재 사용자)
    response.goalInfo = calculateGoalAchievement(currentUserId);
    response.funnelSteps = calculateFunnelAnalysis(currentUserId);

    // 모든 영업사원 데이터
    response.salesReps = getAllSalesRepsData();

    return response;
  }

  // 특정 단계의 기회 목록을 가져오는 메소드
  @AuraEnabled(cacheable=true)
  public static List<Opportunity> getOpportunitiesForStage(
    String stageName,
    String salesRepId
  ) {
    Id targetUserId = String.isNotBlank(salesRepId)
      ? (Id) salesRepId
      : UserInfo.getUserId();

    return [
      SELECT Id, Name, Amount, CloseDate, Account.Phone
      FROM Opportunity
      WHERE
        OwnerId = :targetUserId
        AND StageName = :stageName
        AND IsClosed = FALSE
      ORDER BY CloseDate ASC
      LIMIT 50
    ];
  }

  // --- Private Helper Methods ---

  /**
   * [수정됨] 이번 달 목표 달성률을 계산합니다.
   * Sales_Goal__c 레코드가 없으면 기본 목표를 10으로 설정합니다.
   * 주간 목표 달성률과 일일 평균 필요 성과도 함께 계산합니다.
   */
  private static GoalData calculateGoalAchievement(Id userId) {
    GoalData goalData = new GoalData();

    // 이번 달 목표를 Sales_Goal__c 오브젝트에서 조회
    List<Sales_Goal__c> goals = [
      SELECT Goal_Count__c
      FROM Sales_Goal__c
      WHERE Sales_Rep__c = :userId AND Goal_Month__c = THIS_MONTH
      LIMIT 1
    ];

    // 조회된 목표가 있으면 해당 값을 사용하고, 없으면 기본값 10으로 설정
    if (!goals.isEmpty() && goals[0].Goal_Count__c != null) {
      goalData.goalCount = Integer.valueOf(goals[0].Goal_Count__c);
    } else {
      // [수정] 데이터가 없을 경우, 테스트 및 시연을 위해 기본 목표를 10으로 설정합니다.
      goalData.goalCount = 10;
    }

    // 이번 달에 성공한 기회 건수 계산
    AggregateResult[] closedWon = [
      SELECT COUNT(Id) cnt
      FROM Opportunity
      WHERE
        OwnerId = :userId
        AND StageName = 'Closed Won'
        AND CloseDate = THIS_MONTH
    ];
    goalData.actualCount = (Integer) closedWon[0].get('cnt');

    // 달성률 계산
    if (goalData.goalCount > 0) {
      goalData.achievementRate =
        ((Double) goalData.actualCount / goalData.goalCount) * 100;
    } else {
      goalData.achievementRate = 0.0;
    }

    // 주간 목표 및 일일 평균 계산
    calculateWeeklyAndDailyGoals(goalData, userId);

    return goalData;
  }

  /**
   * 단계별 깔때기 분석 및 전환율을 계산합니다. (변경 없음)
   */
  private static List<FunnelStep> calculateFunnelAnalysis(Id userId) {
    List<String> stageOrder = new List<String>();
    for (
      Schema.PicklistEntry p : Opportunity.StageName.getDescribe()
        .getPicklistValues()
    ) {
      if (!p.getLabel().contains('Closed')) {
        stageOrder.add(p.getLabel());
      }
    }

    Map<String, Integer> currentStageCounts = new Map<String, Integer>();
    for (String stage : stageOrder) {
      currentStageCounts.put(stage, 0);
    }
    for (AggregateResult ar : [
      SELECT StageName, COUNT(Id) cnt
      FROM Opportunity
      WHERE OwnerId = :userId AND IsClosed = FALSE
      GROUP BY StageName
    ]) {
      currentStageCounts.put(
        (String) ar.get('StageName'),
        (Integer) ar.get('cnt')
      );
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
          step.conversionRate =
            ((Double) nextStageReachedCount / currentStageReachedCount) * 100;
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

  /**
   * 모든 영업사원의 데이터를 가져오는 메소드
   */
  private static List<SalesRep> getAllSalesRepsData() {
    List<SalesRep> salesReps = new List<SalesRep>();

    // 기회를 가지고 있는 활성 사용자들을 조회
    List<User> users = [
      SELECT Id, Name
      FROM User
      WHERE
        IsActive = TRUE
        AND Id IN (SELECT OwnerId FROM Opportunity WHERE IsClosed = FALSE)
      ORDER BY Name
      LIMIT 50
    ];

    for (User user : users) {
      SalesRep rep = new SalesRep();
      rep.Id = user.Id;
      rep.Name = user.Name;
      rep.goalInfo = calculateGoalAchievement(user.Id);
      rep.funnelSteps = calculateFunnelAnalysis(user.Id);
      salesReps.add(rep);
    }

    return salesReps;
  }

  /**
   * 주간 목표 달성률과 일일 평균 필요 성과를 계산합니다.
   */
  private static void calculateWeeklyAndDailyGoals(
    GoalData goalData,
    Id userId
  ) {
    Date today = Date.today();
    Date firstDayOfMonth = today.toStartOfMonth();

    // 현재 월의 몇 번째 주인지 계산
    Integer dayOfMonth = today.day();
    goalData.currentWeekOfMonth = (dayOfMonth - 1) / 7 + 1;

    // 이번 달 총 주차 수 계산 (대략적으로 4주로 설정)
    Integer totalWeeksInMonth = 4;

    // 주간 목표 계산 (월 목표를 주차별로 분할)
    goalData.weeklyGoal = (Integer) Math.ceil(
      (Double) goalData.goalCount / totalWeeksInMonth
    );

    // 이번 주에 달성한 실적 계산 (이번 주 시작일부터 오늘까지)
    Date startOfWeek = today.toStartOfWeek();
    AggregateResult[] weeklyClosedWon = [
      SELECT COUNT(Id) cnt
      FROM Opportunity
      WHERE
        OwnerId = :userId
        AND StageName = 'Closed Won'
        AND CloseDate >= :startOfWeek
        AND CloseDate <= :today
    ];
    goalData.weeklyActual = (Integer) weeklyClosedWon[0].get('cnt');

    // 주간 달성률 계산
    if (goalData.weeklyGoal > 0) {
      goalData.weeklyAchievementRate =
        ((Double) goalData.weeklyActual / goalData.weeklyGoal) * 100;
    } else {
      goalData.weeklyAchievementRate = 0.0;
    }

    // 남은 목표 계산
    goalData.remainingGoal = goalData.goalCount - goalData.actualCount;

    // 이번 달 남은 근무일 계산 (주말 제외)
    Date lastDayOfMonth = firstDayOfMonth.addMonths(1).addDays(-1);
    goalData.remainingWorkDays = calculateWorkDays(
      today.addDays(1),
      lastDayOfMonth
    );

    // 일일 평균 필요 성과 계산
    if (goalData.remainingWorkDays > 0 && goalData.remainingGoal > 0) {
      goalData.dailyRequiredAverage =
        (Double) goalData.remainingGoal / goalData.remainingWorkDays;
    } else {
      goalData.dailyRequiredAverage = 0.0;
    }
  }

  /**
   * 두 날짜 사이의 근무일(주말 제외) 수를 계산합니다.
   */
  private static Integer calculateWorkDays(Date startDate, Date endDate) {
    Integer workDays = 0;
    Date currentDate = startDate;

    while (currentDate <= endDate) {
      // 토요일(6), 일요일(0)을 제외한 평일만 카운트
      DateTime dt = DateTime.newInstance(
        currentDate,
        Time.newInstance(0, 0, 0, 0)
      );
      String dayOfWeek = dt.format('u'); // 1=월요일, 7=일요일

      if (dayOfWeek != '6' && dayOfWeek != '7') {
        // 토요일, 일요일이 아닌 경우
        workDays++;
      }
      currentDate = currentDate.addDays(1);
    }

    return workDays;
  }
}
