import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDashboardData from '@salesforce/apex/SalesDashboardController.getDashboardData';
import getOpportunitiesForStage from '@salesforce/apex/SalesDashboardController.getOpportunitiesForStage';

const columns = [
    {
        label: 'Opportunity Name',
        fieldName: 'opportunityUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' },
        sortable: true
    },
    {
        label: 'Amount',
        fieldName: 'Amount',
        type: 'currency',
        typeAttributes: { currencyCode: 'USD' },
        sortable: true
    },
    {
        label: 'Close Date',
        fieldName: 'CloseDate',
        type: 'date-local',
        sortable: true
    },
];

export default class SalesDashboard extends NavigationMixin(LightningElement) {
    dashboardData;
    error;

    @track selectedStage = null;
    @track opportunities = [];
    opportunityColumns = columns;
    isOppLoading = false;

    @wire(getDashboardData)
    wiredData({ error, data }) {
        if (data) {
            this.dashboardData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            console.error('Error fetching dashboard data:', error);
        }
    }

    get isLoading() {
        return (!this.dashboardData && !this.error) || this.isOppLoading;
    }

    get goalCount() {
        return this.dashboardData?.goalInfo.goalCount || 0;
    }
    get actualCount() {
        return this.dashboardData?.goalInfo.actualCount || 0;
    }
    get formattedAchievementRate() {
        const rate = this.dashboardData?.goalInfo.achievementRate || 0;
        return rate.toFixed(1);
    }
    get goalCircleStyle() {
        const rate = this.dashboardData?.goalInfo.achievementRate || 0;
        const cappedRate = Math.min(rate, 100);
        const degree = (cappedRate / 100) * 360;
        return `background: conic-gradient(#0070d2 ${degree}deg, #e0e5ee ${degree}deg);`;
    }

    // [수정] 전환율 표시 로직 전체 수정
    get funnelData() {
        if (!this.dashboardData?.funnelSteps) {
            return [];
        }
        return this.dashboardData.funnelSteps.map(step => {
            // 전환율 값이 null이 아닌 경우에만 (숫자 0 포함) 표시하도록 boolean 값을 설정합니다.
            // Apex에서 마지막 단계의 전환율은 null로 넘어옵니다.
            const showConversion = step.conversionRate != null;

            return {
                ...step,
                // 템플릿(HTML)에서 이 값을 사용하여 조건부 렌더링을 합니다.
                hasConversionRate: showConversion,
                // 전환율을 표시해야 할 때만 소수점 첫째 자리까지 포맷팅합니다.
                formattedConversionRate: showConversion ? step.conversionRate.toFixed(1) : ''
            };
        });
    }

    get hasOpportunities() {
        return this.opportunities && this.opportunities.length > 0;
    }

    handleStageClick(event) {
        this.selectedStage = event.currentTarget.dataset.stage;
        this.isOppLoading = true;
        this.opportunities = [];

        getOpportunitiesForStage({ stageName: this.selectedStage })
            .then(result => {
                this.opportunities = result.map(opp => ({
                    ...opp,
                    opportunityUrl: `/lightning/r/Opportunity/${opp.Id}/view`
                }));
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.opportunities = [];
                console.error('Error fetching opportunities:', error);
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
