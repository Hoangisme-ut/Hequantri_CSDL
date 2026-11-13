import {
  type FeedbackPublic,
  type FeedbackReviewsPublic,
  FeedbacksService,
  type feedbacksReadFeedbacksData,
  type FeedbackStatusUpdate,
} from "@/client"
import { unwrapApi } from "./api-errors"

// Bộ lọc danh sách phản hồi
export type FeedbackFilters = NonNullable<
  feedbacksReadFeedbacksData["query"]
>

// Query keys dành cho React Query
export const feedbackKeys = {
  all: ["feedback"] as const,
  lists: () => [...feedbackKeys.all, "list"] as const,
  list: (filters: FeedbackFilters) =>
    [...feedbackKeys.lists(), filters] as const,
}

// Các hàm gọi Feedback API mới
export const feedbackService = {
  // Lấy danh sách phản hồi dành cho Admin
  async list(filters: FeedbackFilters = {}): Promise<FeedbackReviewsPublic> {
    return unwrapApi(
      FeedbacksService.readFeedbacks({
        query: filters,
      }),
      "Feedback",
    )
  },

  // Duyệt hoặc ẩn phản hồi
  async updateStatus(
    id: string,
    input: FeedbackStatusUpdate,
  ): Promise<FeedbackPublic> {
    return unwrapApi(
      FeedbacksService.moderateFeedback({
        path: { feedback_id: id },
        body: input,
      }),
      "Feedback",
    )
  },
}