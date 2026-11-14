import axios from "axios"
import type {
  analyticsOverviewData,
  analyticsSitesData,
  analyticsTopArtifactsData,
  analyticsVisitsData,
  dashboardReadSummaryData,
  dashboardReadTopArtifactsData,
  dashboardReadVisitsByDayData,
  dashboardReadVisitsByLanguageData,
} from "@/client"
import { AnalyticsService, DashboardService } from "@/client"

import { toApiError, unwrapApi } from "./api-errors"

// Query parameters của nhóm Analytics API
export type AnalyticsOverviewFilters = NonNullable<
  analyticsOverviewData["query"]
>

export type AnalyticsVisitsFilters = NonNullable<analyticsVisitsData["query"]>

export type AnalyticsTopArtifactsFilters = NonNullable<
  analyticsTopArtifactsData["query"]
>

export type AnalyticsSitesFilters = NonNullable<analyticsSitesData["query"]>

// Query parameters của nhóm Dashboard API
export type DashboardSummaryFilters = NonNullable<
  dashboardReadSummaryData["query"]
>

export type DashboardVisitsByDayFilters = NonNullable<
  dashboardReadVisitsByDayData["query"]
>

export type DashboardTopArtifactsFilters = NonNullable<
  dashboardReadTopArtifactsData["query"]
>

export type DashboardVisitsByLanguageFilters = NonNullable<
  dashboardReadVisitsByLanguageData["query"]
>

export type AnalyticsExportFilters = Pick<
  AnalyticsOverviewFilters,
  "from" | "to" | "site_id"
>

async function downloadAnalyticsReport(
  format: "pdf" | "excel",
  filters: AnalyticsExportFilters,
): Promise<void> {
  const token = localStorage.getItem("access_token")

  if (!token) {
    throw new Error("Please sign in as an administrator.")
  }

  try {
    const response = await axios.get(
      `${import.meta.env.VITE_API_URL ?? ""}/api/v1/analytics/export/${format}`,
      {
        params: filters,
        headers: {
          Authorization: `Bearer ${token}`,
        },
        responseType: "blob",
      },
    )

    const mimeType =
      format === "pdf"
        ? "application/pdf"
        : "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    const blob = new Blob([response.data], { type: mimeType })
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")

    link.href = url
    link.download = `analytics-report.${format === "pdf" ? "pdf" : "xlsx"}`

    document.body.appendChild(link)
    link.click()
    link.remove()

    URL.revokeObjectURL(url)
  } catch (error) {
    throw toApiError(error, "Analytics export")
  }
}

export const analyticsService = {
  // Tổng quan lượt xem, người xem và hiện vật được xem
  async overview(filters: AnalyticsOverviewFilters = {}) {
    return unwrapApi(
      AnalyticsService.overview({ query: filters }),
      "Analytics overview",
    )
  },

  // Lượt xem theo ngày
  async visits(filters: AnalyticsVisitsFilters = {}) {
    return unwrapApi(
      AnalyticsService.visits({ query: filters }),
      "Analytics visits",
    )
  },

  // Hiện vật được xem nhiều nhất
  async topArtifacts(filters: AnalyticsTopArtifactsFilters = {}) {
    return unwrapApi(
      AnalyticsService.topArtifacts({ query: filters }),
      "Top artifacts",
    )
  },

  // Thống kê lượt xem theo Site
  async sites(filters: AnalyticsSitesFilters = {}) {
    return unwrapApi(
      AnalyticsService.sites({ query: filters }),
      "Site analytics",
    )
  },

  // Tổng quan số lượng Site, Artifact, Beacon và đánh giá
  async summary(filters: DashboardSummaryFilters = {}) {
    return unwrapApi(
      DashboardService.readSummary({ query: filters }),
      "Dashboard summary",
    )
  },

  // Lượt xem theo ngày, có đủ cả ngày không phát sinh lượt xem
  async visitsByDay(filters: DashboardVisitsByDayFilters = {}) {
    return unwrapApi(
      DashboardService.readVisitsByDay({ query: filters }),
      "Visits by day",
    )
  },

  // Top hiện vật theo số lượt xem
  async dashboardTopArtifacts(filters: DashboardTopArtifactsFilters = {}) {
    return unwrapApi(
      DashboardService.readTopArtifacts({ query: filters }),
      "Dashboard top artifacts",
    )
  },

  // Thống kê lượt xem theo ngôn ngữ
  async visitsByLanguage(filters: DashboardVisitsByLanguageFilters = {}) {
    return unwrapApi(
      DashboardService.readVisitsByLanguage({ query: filters }),
      "Visits by language",
    )
  },

  // Xuất báo cáo PDF
  async exportPdf(filters: AnalyticsExportFilters = {}) {
    return downloadAnalyticsReport("pdf", filters)
  },

  // Xuất báo cáo Excel
  async exportExcel(filters: AnalyticsExportFilters = {}) {
    return downloadAnalyticsReport("excel", filters)
  },
}
