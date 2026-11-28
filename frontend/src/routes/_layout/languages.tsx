import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { createFileRoute } from "@tanstack/react-router"
import { isAxiosError } from "axios"
import { type FormEvent, useState } from "react"
import { toast } from "sonner"

import {
  type LanguageCreate,
  type LanguagePublic,
  LanguagesService,
  type LanguageUpdate,
} from "@/client"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { languageKeys } from "@/services/translations"

export const Route = createFileRoute("/_layout/languages")({
  component: LanguagesPage,
  head: () => ({ meta: [{ title: "Quản lý ngôn ngữ - Smart Heritage" }] }),
})

type Change =
  | { id?: undefined; body: LanguageCreate }
  | { id: string; body: LanguageUpdate }

const defaultHint = "Hãy đặt một ngôn ngữ khác làm mặc định trước khi tắt."

function errorMessage(error: unknown) {
  if (!isAxiosError<{ detail?: unknown }>(error) || !error.response) {
    return "Không thể kết nối đến máy chủ. Hãy kiểm tra kết nối và thử lại."
  }
  switch (error.response.status) {
    case 400:
      return `Ngôn ngữ mặc định phải đang hoạt động. ${defaultHint}`
    case 401:
      return "Phiên đăng nhập đã hết hạn."
    case 403:
      return "Bạn cần quyền quản trị để quản lý ngôn ngữ."
    case 404:
      return "Không tìm thấy ngôn ngữ đã chọn."
    case 409:
      return error.response.data?.detail === "Language code already exists"
        ? "Mã ngôn ngữ đã tồn tại."
        : "Dữ liệu bị xung đột. Hãy kiểm tra danh sách rồi thử lại."
    case 422:
      return "Dữ liệu không hợp lệ. Hãy kiểm tra mã, tên và trạng thái."
    default:
      return "Máy chủ không xử lý được yêu cầu. Vui lòng thử lại."
  }
}

function LanguagesPage() {
  const queryClient = useQueryClient()
  const [editor, setEditor] = useState<LanguagePublic | "new" | null>(null)
  const [formError, setFormError] = useState("")
  const editing = editor === "new" ? null : editor
  const languages = useQuery({
    queryKey: [...languageKeys.all, "admin"],
    queryFn: async () =>
      (
        await LanguagesService.readLanguages({
          query: { include_inactive: true },
        })
      ).data.data,
  })

  const save = useMutation({
    mutationFn: async (change: Change) => {
      if (change.id === undefined) {
        await LanguagesService.createLanguage({ body: change.body })
      } else {
        await LanguagesService.updateLanguage({
          path: { language_id: change.id },
          body: change.body,
        })
      }
    },
    onSuccess: (_, change) =>
      toast.success(change.id ? "Đã cập nhật ngôn ngữ." : "Đã thêm ngôn ngữ."),
    onError: (error) => toast.error(errorMessage(error)),
    onSettled: async () => {
      setEditor(null)
      await queryClient.invalidateQueries({ queryKey: languageKeys.all })
    },
  })

  function openEditor(value: LanguagePublic | "new") {
    setFormError("")
    setEditor(value)
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const fields = new FormData(event.currentTarget)
    const code = (editing?.code ?? String(fields.get("code") ?? "")).trim()
    const name = String(fields.get("name") ?? "").trim()
    if (!code || code.length > 10 || !name || name.length > 100) {
      setFormError("Nhập mã từ 1 đến 10 ký tự và tên từ 1 đến 100 ký tự.")
      return
    }
    const active = editing?.is_default || fields.has("active")
    if (editing) {
      const body: LanguageUpdate = { name }
      if (active !== editing.is_active) body.is_active = active
      save.mutate({ id: editing.id, body })
    } else {
      save.mutate({ body: { code, name, is_active: active } })
    }
  }

  function makeDefault(language: LanguagePublic) {
    if (
      window.confirm(
        `Đặt ${language.name} (${language.code}) làm ngôn ngữ mặc định?`,
      )
    ) {
      save.mutate({ id: language.id, body: { is_default: true } })
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-2xl font-bold tracking-tight">
          Danh sách ngôn ngữ
        </h2>
        <Button disabled={save.isPending} onClick={() => openEditor("new")}>
          Thêm ngôn ngữ
        </Button>
      </div>
      {languages.isPending && <p role="status">Đang tải danh sách ngôn ngữ…</p>}
      {languages.isError && (
        <div className="space-y-2" role="alert">
          <p>{errorMessage(languages.error)}</p>
          <Button variant="outline" onClick={() => void languages.refetch()}>
            Thử lại
          </Button>
        </div>
      )}
      {languages.isSuccess &&
        (languages.data.length === 0 ? (
          <p>Chưa có ngôn ngữ nào.</p>
        ) : (
          <Table aria-label="Danh sách ngôn ngữ">
            <TableHeader>
              <TableRow>
                <TableHead>Mã</TableHead>
                <TableHead>Tên</TableHead>
                <TableHead>Trạng thái</TableHead>
                <TableHead>Thao tác</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {languages.data.map((language) => (
                <TableRow key={language.id}>
                  <TableCell>{language.code}</TableCell>
                  <TableCell className="font-medium">
                    {language.name}{" "}
                    {language.is_default && <Badge>Mặc định</Badge>}
                  </TableCell>
                  <TableCell>
                    {language.is_active ? "Hoạt động" : "Tắt"}
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-wrap gap-2">
                      <Button
                        size="sm"
                        variant="outline"
                        disabled={save.isPending}
                        onClick={() => openEditor(language)}
                      >
                        Sửa
                      </Button>
                      <span
                        title={language.is_default ? defaultHint : undefined}
                      >
                        <Button
                          size="sm"
                          variant="outline"
                          disabled={save.isPending || language.is_default}
                          onClick={() =>
                            save.mutate({
                              id: language.id,
                              body: { is_active: !language.is_active },
                            })
                          }
                        >
                          {language.is_active ? "Tắt" : "Bật"}
                        </Button>
                      </span>
                      {language.is_active && !language.is_default && (
                        <Button
                          size="sm"
                          variant="outline"
                          disabled={save.isPending}
                          onClick={() => makeDefault(language)}
                        >
                          Đặt làm mặc định
                        </Button>
                      )}
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        ))}
      <Dialog
        open={editor !== null}
        onOpenChange={(open) => {
          if (!open && !save.isPending) setEditor(null)
        }}
      >
        <DialogContent aria-describedby={undefined} showCloseButton={false}>
          <DialogHeader>
            <DialogTitle>
              {editing ? "Sửa ngôn ngữ" : "Thêm ngôn ngữ"}
            </DialogTitle>
          </DialogHeader>
          <form
            key={editing?.id ?? "new"}
            className="space-y-4"
            onSubmit={submit}
          >
            <div className="space-y-2">
              <Label htmlFor="language-code">Mã ngôn ngữ</Label>
              <Input
                id="language-code"
                name="code"
                defaultValue={editing?.code}
                readOnly={!!editing}
                required
                maxLength={10}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="language-name">Tên ngôn ngữ</Label>
              <Input
                id="language-name"
                name="name"
                defaultValue={editing?.name}
                required
                maxLength={100}
              />
            </div>
            <Label title={editing?.is_default ? defaultHint : undefined}>
              <input
                type="checkbox"
                name="active"
                defaultChecked={editing?.is_active ?? true}
                disabled={editing?.is_default}
              />{" "}
              Hoạt động
            </Label>
            {formError && (
              <p role="alert" className="text-sm text-destructive">
                {formError}
              </p>
            )}
            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                disabled={save.isPending}
                onClick={() => setEditor(null)}
              >
                Hủy
              </Button>
              <Button type="submit" disabled={save.isPending}>
                {save.isPending ? "Đang lưu…" : "Lưu"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  )
}
