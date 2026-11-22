import { isAxiosError } from "axios"
import {
  type FeedbackAdminStatusUpdate,
  type FeedbackPublic,
  type FeedbackReviewsPublic,
  FeedbacksService,
  type feedbacksReadFeedbacksData,
} from "@/client"
import { toApiError, unwrapApi } from "./api-errors"

export class FeedbackConflictError extends Error {
  constructor() {
    super(
      "Feedback changed. Review the latest content before moderating again.",
    )
  }
}

// Bộ lọc danh sách phản hồi
export type FeedbackFilters = NonNullable<feedbacksReadFeedbacksData["query"]>

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
    input: FeedbackAdminStatusUpdate,
  ): Promise<FeedbackPublic> {
    try {
      const response = await FeedbacksService.moderateFeedback({
        path: { feedback_id: id },
        body: input,
      })
      return response.data
    } catch (error) {
      if (isAxiosError(error) && error.response?.status === 409) {
        throw new FeedbackConflictError()
      }
      throw toApiError(error, "Feedback")
    }
  },
}
