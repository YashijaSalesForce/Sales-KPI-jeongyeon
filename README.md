# 📊 Salesforce Mobile KPI Dashboard

<div align="center">
  
[![Salesforce](https://img.shields.io/badge/Salesforce-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white)](https://salesforce.com)
[![LWC](https://img.shields.io/badge/Lightning_Web_Components-0176D3?style=for-the-badge&logo=salesforce&logoColor=white)](https://developer.salesforce.com/docs/component-library/overview/components)
[![Apex](https://img.shields.io/badge/Apex-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white)](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/)

</div>

## 🎯 프로젝트 개요

영업 현장에서 **실시간 KPI 모니터링**이 필요한 영업사원들을 위한 **모바일 최적화 대시보드** 솔루션입니다.  
LWC(Lightning Web Components)와 Apex를 활용하여 언제 어디서나 성과를 확인하고 관리할 수 있습니다.

---

## 🔴 (As-Is)

<table>
<tr>
<th>문제점</th>
<th>영향</th>
<th>Pain Point</th>
</tr>
<tr>
<td>📝 수동 계산</td>
<td>Excel로 KPI 수동 계산</td>
<td>일일 평균 30분+ 소요건
```bash
# Salesforce CLI 설치 확인
sfdx --version

# Node.js 버전 확인 (14.x 이상)
node --version
```

### 설치
```bash
# 1. Repository 클론
git clone https://github.com/your-username/salesforce-kpi-dashboard.git

# 2. 프로젝트 디렉토리 이동
cd salesforce-kpi-dashboard

# 3. 의존성 설치
npm install

# 4. Salesforce 조직에 배포
sfdx force:source:deploy -p force-app/main/default
```

### 구축
```javascript
// config/kpi-settings.json
{
  "refreshInterval": 300000,  // 5분마다 자동 갱신
  "enableNotifications": true,
  "weeklyTargetCalculation": "auto",
  "workingDays": ["MON", "TUE", "WED", "THU", "FRI"]
}
```

---

## 🛣️ 로드맵

- [x] 기본 KPI 대시보드 구현
- [x] 주간/일일 목표 계산 기능
- [x] 모바일 반응형 디자인
- [ ] AI 기반 성과 예측 모델
- [ ] 푸시 알림 시스템
- [ ] 오프라인 모드 지원
- [ ] 다국어 지원


---



<div align="center">


</div>
