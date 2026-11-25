import { zodResolver } from "@hookform/resolvers/zod"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { Pencil } from "lucide-react"
import { useEffect, useState } from "react"
import { useForm } from "react-hook-form"
import { z } from "zod"

import {
  type RolePublic,
  type UserPublic,
  RolesService,
  UsersService,
  type UserUpdate,
} from "@/client"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { DropdownMenuItem } from "@/components/ui/dropdown-menu"
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { LoadingButton } from "@/components/ui/loading-button"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import useCustomToast from "@/hooks/useCustomToast"
import { handleError } from "@/utils"

const formSchema = z
  .object({
    email: z.email({ message: "Invalid email address" }),
    full_name: z.string().optional(),
    password: z
      .string()
      .min(8, { message: "Password must be at least 8 characters" })
      .optional()
      .or(z.literal("")),
    confirm_password: z.string().optional(),
    account_type: z.enum(["visitor", "admin", "superuser"]),
    is_active: z.boolean().optional(),
  })
  .refine((data) => !data.password || data.password === data.confirm_password, {
    message: "The passwords don't match",
    path: ["confirm_password"],
  })

type FormData = z.infer<typeof formSchema>

interface EditUserProps {
  user: UserPublic
  onSuccess: () => void
}

const EditUser = ({ user, onSuccess }: EditUserProps) => {
  const [isOpen, setIsOpen] = useState(false)
  const queryClient = useQueryClient()
  const { showSuccessToast, showErrorToast } = useCustomToast()

  const rolesQuery = useQuery({
    queryKey: ["roles"],
    queryFn: async () => (await RolesService.readRoles()).data,
  })

  const form = useForm<FormData>({
    resolver: zodResolver(formSchema),
    mode: "onBlur",
    criteriaMode: "all",
    defaultValues: {
      email: user.email,
      full_name: user.full_name ?? "",
      password: "",
      confirm_password: "",
      account_type: user.is_superuser ? "superuser" : "visitor",
      is_active: user.is_active,
    },
  })

  // Đồng bộ dữ liệu tài khoản mỗi khi mở hộp thoại.
  useEffect(() => {
    if (!isOpen || !rolesQuery.isSuccess) return

    const currentRole = rolesQuery.data.find(
      (role: RolePublic) => role.id === user.role_id,
    )

    const accountType = user.is_superuser
      ? "superuser"
      : currentRole?.name === "admin"
        ? "admin"
        : "visitor"

    form.reset({
      email: user.email,
      full_name: user.full_name ?? "",
      password: "",
      confirm_password: "",
      account_type: accountType,
      is_active: user.is_active,
    })
  }, [isOpen, rolesQuery.isSuccess, rolesQuery.data, user, form])

  const mutation = useMutation({
    mutationFn: (data: UserUpdate) =>
      UsersService.updateUser({
        path: { user_id: user.id },
        body: data,
      }),
    onSuccess: () => {
      showSuccessToast("User updated successfully")
      setIsOpen(false)
      onSuccess()
    },
    onError: handleError.bind(showErrorToast),
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] })
    },
  })

  const onSubmit = (data: FormData) => {
    const { dirtyFields } = form.formState
    const submitData: UserUpdate = {}
    if (dirtyFields.email) {
      submitData.email = data.email
    }
    if (dirtyFields.full_name) {
      submitData.full_name = data.full_name
    }

    // Khi thay đổi loại tài khoản, cập nhật đồng thời role_id và is_superuser.
    if (dirtyFields.account_type) {
      const roleName =
        data.account_type === "visitor" ? "visitor" : "admin"

      const role = rolesQuery.data?.find(
        (item: RolePublic) => item.name === roleName,
      )

      if (!role) {
        showErrorToast("Unable to find the selected account role")
        return
      }

      submitData.role_id = role.id
      submitData.is_superuser = data.account_type === "superuser"
    }
    if (dirtyFields.is_active) {
      submitData.is_active = data.is_active
    }
    if (dirtyFields.password && data.password) {
      submitData.password = data.password
    }
    if (Object.keys(submitData).length === 0) return

    mutation.mutate(submitData)
  }

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DropdownMenuItem
        onSelect={(e) => e.preventDefault()}
        onClick={() => setIsOpen(true)}
      >
        <Pencil />
        Edit User
      </DropdownMenuItem>
      <DialogContent className="sm:max-w-md">
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)}>
            <DialogHeader>
              <DialogTitle>Edit User</DialogTitle>
              <DialogDescription>
                Update the user details below.
              </DialogDescription>
            </DialogHeader>
            <div className="grid gap-4 py-4">
              <FormField
                control={form.control}
                name="email"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>
                      Email <span className="text-destructive">*</span>
                    </FormLabel>
                    <FormControl>
                      <Input
                        placeholder="Email"
                        type="email"
                        {...field}
                        required
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="full_name"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Full Name</FormLabel>
                    <FormControl>
                      <Input
                        placeholder="Full name"
                        type="text"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="password"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Set Password</FormLabel>
                    <FormControl>
                      <Input
                        placeholder="Password"
                        type="password"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="confirm_password"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Confirm Password</FormLabel>
                    <FormControl>
                      <Input
                        placeholder="Password"
                        type="password"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="account_type"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Account Type</FormLabel>
                    <Select
                      value={field.value}
                      onValueChange={field.onChange}
                      disabled={!rolesQuery.isSuccess}
                    >
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select account type" />
                        </SelectTrigger>
                      </FormControl>

                      <SelectContent>
                        <SelectItem value="visitor">Visitor</SelectItem>
                        <SelectItem value="admin">Admin</SelectItem>
                        <SelectItem value="superuser">Superuser</SelectItem>
                      </SelectContent>
                    </Select>

                    <FormMessage />

                    {rolesQuery.isLoading && (
                      <p className="text-xs text-muted-foreground">
                        Loading account roles...
                      </p>
                    )}

                    {rolesQuery.isError && (
                      <p className="text-xs text-destructive">
                        Unable to load account roles. Please try again.
                      </p>
                    )}
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="is_active"
                render={({ field }) => (
                  <FormItem className="flex items-center gap-3 space-y-0">
                    <FormControl>
                      <Checkbox
                        checked={field.value}
                        onCheckedChange={field.onChange}
                      />
                    </FormControl>
                    <FormLabel className="font-normal">
                      Is active?
                    </FormLabel>
                  </FormItem>
                )}
              />
            </div>

            <DialogFooter>
              <DialogClose asChild>
                <Button variant="outline" disabled={mutation.isPending}>
                  Cancel
                </Button>
              </DialogClose>
              <LoadingButton
                type="submit"
                loading={mutation.isPending}
                disabled={!form.formState.isDirty}
              >
                Save
              </LoadingButton>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}

export default EditUser
