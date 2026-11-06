import {
  FeedbackService,
  type FeedbackPublic,
  type FeedbackReviewsPublic,
  type FeedbackStatusUpdate,
  type feedbackReadFeedbacksData,
} from "@/client"
import { unwrapApi } from "./api-errors"

// Bộ lọc danh sách phản hồi
export type FeedbackFilters = NonNullable<
  feedbackReadFeedbacksData["query"]
>

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
  async list(
    filters: FeedbackFilters = {},
  ): Promise<FeedbackReviewsPublic> {
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
    input: FeedbackStatusUpdate,
  ): Promise<FeedbackPublic> {
    return unwrapApi(
      FeedbackService.updateFeedbackStatus({
        path: { feedback_id: id },
        body: input,
      }),
      "Feedback",
    )
  },
}