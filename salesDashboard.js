import { LightningElement, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getDashboardData from "@salesforce/apex/SalesDashboardController.getDashboardData";
import getOpportunitiesForStage from "@salesforce/apex/SalesDashboardController.getOpportunitiesForStage";

const columns = [
  {
    label: "Opportunity Name",
    fieldName: "opportunityUrl",
    type: "url",
    typeAttributes: { label: { fieldName: "Name" }, target: "_blank" },
    sortable: true
  },
  {
    label: "Phone",
    fieldName: "Account.Phone",
    type: "phone",
    sortable: true
  },
  {
    label: "Close Date",
    fieldName: "CloseDate",
    type: "date-local",
    sortable: true
  }
];

export default class SalesDashboard extends NavigationMixin(LightningElement) {
  dashboardData;
  error;

  @track selectedStage = null;
  @track selectedSalesRep = null;
  @track opportunities = [];
  opportunityColumns = columns;
  isOppLoading = false;

  @wire(getDashboardData)
  wiredData({ error, data }) {
    if (data) {
      this.dashboardData = data;
      this.error = undefined;
      // 기본적으로 첫 번째 영업사원을 선택 (전체 보기)
      if (
        !this.selectedSalesRep &&
        data.salesReps &&
        data.salesReps.length > 0
      ) {
        this.selectedSalesRep = null; // 전체 보기로 시작
      }
    } else if (error) {
      this.error = error;
      console.error("Error fetching dashboard data:", error);
    }
  }

  renderedCallback() {
    // 동적으로 progress circle 스타일 적용
    const progressCircle = this.template.querySelector(".goal-progress-circle");
    if (progressCircle) {
      const data = this.currentSalesRepData;
      const rate = data?.goalInfo?.achievementRate || 0;
      const cappedRate = Math.min(rate, 100);
      const degree = (cappedRate / 100) * 360;
      progressCircle.style.setProperty("--progress-degree", `${degree}deg`);
    }
  }

  get isLoading() {
    return (!this.dashboardData && !this.error) || this.isOppLoading;
  }

  get salesRepOptions() {
    if (!this.dashboardData?.salesReps) {
      return [];
    }
    return [
      { label: "전체 영업사원", value: null },
      ...this.dashboardData.salesReps.map((rep) => ({
        label: rep.Name,
        value: rep.Id
      }))
    ];
  }

  get currentSalesRepData() {
    if (!this.selectedSalesRep || !this.dashboardData?.salesReps) {
      return this.dashboardData;
    }
    return this.dashboardData.salesReps.find(
      (rep) => rep.Id === this.selectedSalesRep
    );
  }

  get selectedSalesRepName() {
    if (!this.selectedSalesRep || !this.dashboardData?.salesReps) {
      return "";
    }
    const rep = this.dashboardData.salesReps.find(
      (rep) => rep.Id === this.selectedSalesRep
    );
    return rep ? rep.Name : "";
  }

  get goalCount() {
    const data = this.currentSalesRepData;
    return data?.goalInfo?.goalCount || 0;
  }
  get actualCount() {
    const data = this.currentSalesRepData;
    return data?.goalInfo?.actualCount || 0;
  }
  get formattedAchievementRate() {
    const data = this.currentSalesRepData;
    const rate = data?.goalInfo?.achievementRate || 0;
    return rate.toFixed(1);
  }

  // [수정] 전환율 표시 로직 전체 수정
  get funnelData() {
    const data = this.currentSalesRepData;
    if (!data?.funnelSteps) {
      return [];
    }
    return data.funnelSteps.map((step) => {
      // 전환율 값이 null이 아닌 경우에만 (숫자 0 포함) 표시하도록 boolean 값을 설정합니다.
      // Apex에서 마지막 단계의 전환율은 null로 넘어옵니다.
      const showConversion = step.conversionRate != null;

      return {
        ...step,
        // 템플릿(HTML)에서 이 값을 사용하여 조건부 렌더링을 합니다.
        hasConversionRate: showConversion,
        // 전환율을 표시해야 할 때만 소수점 첫째 자리까지 포맷팅합니다.
        formattedConversionRate: showConversion
          ? step.conversionRate.toFixed(1)
          : ""
      };
    });
  }

  get hasOpportunities() {
    return this.opportunities && this.opportunities.length > 0;
  }

  handleSalesRepChange(event) {
    this.selectedSalesRep = event.detail.value;
    // 영업사원을 변경하면 선택된 스테이지와 기회 목록 초기화
    this.selectedStage = null;
    this.opportunities = [];
  }

  handleStageClick(event) {
    this.selectedStage = event.currentTarget.dataset.stage;
    this.isOppLoading = true;
    this.opportunities = [];

    const params = {
      stageName: this.selectedStage
    };

    // 특정 영업사원이 선택된 경우 해당 사원의 기회만 조회
    if (this.selectedSalesRep) {
      params.salesRepId = this.selectedSalesRep;
    }

    getOpportunitiesForStage(params)
      .then((result) => {
        this.opportunities = result.map((opp) => ({
          ...opp,
          opportunityUrl: `/lightning/r/Opportunity/${opp.Id}/view`
        }));
        this.error = undefined;
      })
      .catch((error) => {
        this.error = error;
        this.opportunities = [];
        console.error("Error fetching opportunities:", error);
      })
      .finally(() => {
        this.isOppLoading = false;
      });
  }

  handleBackClick() {
    this.selectedStage = null;
    this.opportunities = [];
  }
}
