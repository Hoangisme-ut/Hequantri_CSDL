import {
  type FeedbackPublic,
  type FeedbackReviewsPublic,
  FeedbackService,
  type feedbackReadFeedbacksData,
  type LegacyFeedbackStatusUpdate,
} from "@/client"
import { unwrapApi } from "./api-errors"

// Bộ lọc danh sách phản hồi
export type FeedbackFilters = NonNullable<feedbackReadFeedbacksData["query"]>

// Query keys dành cho React Query
export const feedbackKeys = {
  all: ["feedback"] as const,
  lists: () => [...feedbackKeys.all, "list"] as const,
  list: (filters: FeedbackFilters) =>
    [...feedbackKeys.lists(), filters] as const,
}

// Các hàm gọi Feedback API
export const feedbackService = {
  // Lấy danh sách phản hồi
  async list(filters: FeedbackFilters = {}): Promise<FeedbackReviewsPublic> {
    return unwrapApi(
      FeedbackService.readFeedbacks({
        query: filters,
      }),
      "Feedback",
    )
  },

  // Duyệt hoặc từ chối phản hồi
  async updateStatus(
    id: string,
    input: LegacyFeedbackStatusUpdate,
  ): Promise<FeedbackPublic> {
    return unwrapApi(
      FeedbackService.moderateFeedback({
        path: { feedback_id: id },
        body: input,
      }),
      "Feedback",
    )
  },
}
