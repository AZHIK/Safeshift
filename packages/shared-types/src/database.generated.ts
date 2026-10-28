
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "public": {
          Tables: {
            "addresses": {
                  Row: {
                    "city_id": string | null,"country_id": string,"created_at": string,"created_by": string | null,"id": string,"landmark": string | null,"line_1": string,"line_2": string | null,"location": unknown,"metadata": NonNullable<Json>,"neighborhood_id": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "city_id"?: string | null,"country_id": string,"created_at"?: string,"created_by"?: string | null,"id"?: string,"landmark"?: string | null,"line_1": string,"line_2"?: string | null,"location": unknown,"metadata"?: NonNullable<Json>,"neighborhood_id"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "city_id"?: string | null,"country_id"?: string,"created_at"?: string,"created_by"?: string | null,"id"?: string,"landmark"?: string | null,"line_1"?: string,"line_2"?: string | null,"location"?: unknown,"metadata"?: NonNullable<Json>,"neighborhood_id"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "addresses_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "addresses_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "addresses_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "addresses_neighborhood_id_fkey"
      columns: ["neighborhood_id"]
isOneToOne: false
      referencedRelation: "neighborhoods"
      referencedColumns: ["id"]
    }
                  ]
                },"admin_actions_log": {
                  Row: {
                    "action": string,"admin_profile_id": string,"admin_role": string,"created_at": string,"entity_id": string | null,"entity_type": string | null,"id": number,"ip_address": unknown,"new_value": Json | null,"old_value": Json | null,"permission_used": string | null,"user_agent": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "action": string,"admin_profile_id": string,"admin_role": string,"created_at"?: string,"entity_id"?: string | null,"entity_type"?: string | null,"id"?: never,"ip_address"?: unknown,"new_value"?: Json | null,"old_value"?: Json | null,"permission_used"?: string | null,"user_agent"?: string | null
                  }
                  Update: {
                    "action"?: string,"admin_profile_id"?: string,"admin_role"?: string,"created_at"?: string,"entity_id"?: string | null,"entity_type"?: string | null,"id"?: never,"ip_address"?: unknown,"new_value"?: Json | null,"old_value"?: Json | null,"permission_used"?: string | null,"user_agent"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "admin_actions_log_admin_profile_id_fkey"
      columns: ["admin_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"admin_permissions_catalog": {
                  Row: {
                    "category": string | null,"created_at": string,"description": string,"id": string,"permission_key": string
                  }
                  ComputedFields: never
                  Insert: {
                    "category"?: string | null,"created_at"?: string,"description": string,"id"?: string,"permission_key": string
                  }
                  Update: {
                    "category"?: string | null,"created_at"?: string,"description"?: string,"id"?: string,"permission_key"?: string
                  }
                  Relationships: [
                    
                  ]
                },"admin_role_permissions": {
                  Row: {
                    "created_at": string,"id": string,"permission_key": string,"role_name": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"permission_key": string,"role_name": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"permission_key"?: string,"role_name"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "admin_role_permissions_permission_key_fkey"
      columns: ["permission_key"]
isOneToOne: false
      referencedRelation: "admin_permissions_catalog"
      referencedColumns: ["permission_key"]
    }
                  ]
                },"admin_roles": {
                  Row: {
                    "city_id": string | null,"country_id": string | null,"created_at": string,"expires_at": string | null,"granted_at": string,"granted_by": string | null,"id": string,"is_active": boolean,"profile_id": string,"revoked_at": string | null,"revoked_reason": string | null,"role_name": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "city_id"?: string | null,"country_id"?: string | null,"created_at"?: string,"expires_at"?: string | null,"granted_at"?: string,"granted_by"?: string | null,"id"?: string,"is_active"?: boolean,"profile_id": string,"revoked_at"?: string | null,"revoked_reason"?: string | null,"role_name": string,"updated_at"?: string
                  }
                  Update: {
                    "city_id"?: string | null,"country_id"?: string | null,"created_at"?: string,"expires_at"?: string | null,"granted_at"?: string,"granted_by"?: string | null,"id"?: string,"is_active"?: boolean,"profile_id"?: string,"revoked_at"?: string | null,"revoked_reason"?: string | null,"role_name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "admin_roles_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "admin_roles_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "admin_roles_granted_by_fkey"
      columns: ["granted_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "admin_roles_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"blocked_users": {
                  Row: {
                    "blocked_profile_id": string,"blocker_profile_id": string,"created_at": string,"id": string,"job_id": string | null,"reason": string | null,"scope": string
                  }
                  ComputedFields: never
                  Insert: {
                    "blocked_profile_id": string,"blocker_profile_id": string,"created_at"?: string,"id"?: string,"job_id"?: string | null,"reason"?: string | null,"scope"?: string
                  }
                  Update: {
                    "blocked_profile_id"?: string,"blocker_profile_id"?: string,"created_at"?: string,"id"?: string,"job_id"?: string | null,"reason"?: string | null,"scope"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "blocked_users_blocked_profile_id_fkey"
      columns: ["blocked_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "blocked_users_blocker_profile_id_fkey"
      columns: ["blocker_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "blocked_users_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "blocked_users_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "blocked_users_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "blocked_users_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"business_accounts": {
                  Row: {
                    "billing_address_id": string | null,"city_id": string | null,"contact_email": string | null,"contact_phone": string | null,"country_id": string,"created_at": string,"credit_limit": number,"current_balance": number,"id": string,"industry": string | null,"is_active": boolean,"legal_name": string,"payment_terms_days": number,"registration_number": string | null,"tax_id": string | null,"trading_name": string | null,"updated_at": string,"verified_at": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "billing_address_id"?: string | null,"city_id"?: string | null,"contact_email"?: string | null,"contact_phone"?: string | null,"country_id": string,"created_at"?: string,"credit_limit"?: number,"current_balance"?: number,"id"?: string,"industry"?: string | null,"is_active"?: boolean,"legal_name": string,"payment_terms_days"?: number,"registration_number"?: string | null,"tax_id"?: string | null,"trading_name"?: string | null,"updated_at"?: string,"verified_at"?: string | null
                  }
                  Update: {
                    "billing_address_id"?: string | null,"city_id"?: string | null,"contact_email"?: string | null,"contact_phone"?: string | null,"country_id"?: string,"created_at"?: string,"credit_limit"?: number,"current_balance"?: number,"id"?: string,"industry"?: string | null,"is_active"?: boolean,"legal_name"?: string,"payment_terms_days"?: number,"registration_number"?: string | null,"tax_id"?: string | null,"trading_name"?: string | null,"updated_at"?: string,"verified_at"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "business_accounts_billing_address_id_fkey"
      columns: ["billing_address_id"]
isOneToOne: false
      referencedRelation: "addresses"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "business_accounts_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "business_accounts_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    }
                  ]
                },"business_members": {
                  Row: {
                    "accepted_at": string | null,"business_account_id": string,"created_at": string,"id": string,"invited_at": string | null,"profile_id": string,"role": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "accepted_at"?: string | null,"business_account_id": string,"created_at"?: string,"id"?: string,"invited_at"?: string | null,"profile_id": string,"role": string,"updated_at"?: string
                  }
                  Update: {
                    "accepted_at"?: string | null,"business_account_id"?: string,"created_at"?: string,"id"?: string,"invited_at"?: string | null,"profile_id"?: string,"role"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "business_members_business_account_id_fkey"
      columns: ["business_account_id"]
isOneToOne: false
      referencedRelation: "business_accounts"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "business_members_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"cancellation_policies": {
                  Row: {
                    "applies_to_role": Database["public"]['Enums']["user_role"],"country_id": string,"created_at": string,"currency_code": string | null,"description": string | null,"fee_tiers": Json | null,"fee_type": string,"fee_value": number,"free_cancellation_window_minutes": number,"id": string,"is_active": boolean,"name": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "applies_to_role": Database["public"]['Enums']["user_role"],"country_id": string,"created_at"?: string,"currency_code"?: string | null,"description"?: string | null,"fee_tiers"?: Json | null,"fee_type": string,"fee_value"?: number,"free_cancellation_window_minutes"?: number,"id"?: string,"is_active"?: boolean,"name": string,"updated_at"?: string
                  }
                  Update: {
                    "applies_to_role"?: Database["public"]['Enums']["user_role"],"country_id"?: string,"created_at"?: string,"currency_code"?: string | null,"description"?: string | null,"fee_tiers"?: Json | null,"fee_type"?: string,"fee_value"?: number,"free_cancellation_window_minutes"?: number,"id"?: string,"is_active"?: boolean,"name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "cancellation_policies_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "cancellation_policies_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    }
                  ]
                },"cargo_categories": {
                  Row: {
                    "code": string,"created_at": string,"description": string | null,"display_order": number,"icon_url": string | null,"id": string,"is_active": boolean,"name": string,"parent_category_id": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "code": string,"created_at"?: string,"description"?: string | null,"display_order"?: number,"icon_url"?: string | null,"id"?: string,"is_active"?: boolean,"name": string,"parent_category_id"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "code"?: string,"created_at"?: string,"description"?: string | null,"display_order"?: number,"icon_url"?: string | null,"id"?: string,"is_active"?: boolean,"name"?: string,"parent_category_id"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "cargo_categories_parent_category_id_fkey"
      columns: ["parent_category_id"]
isOneToOne: false
      referencedRelation: "cargo_categories"
      referencedColumns: ["id"]
    }
                  ]
                },"cargo_packaging_options": {
                  Row: {
                    "additional_fee_tzs": number,"code": string,"created_at": string,"description": string | null,"display_order": number,"id": string,"is_active": boolean,"name": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "additional_fee_tzs"?: number,"code": string,"created_at"?: string,"description"?: string | null,"display_order"?: number,"id"?: string,"is_active"?: boolean,"name": string,"updated_at"?: string
                  }
                  Update: {
                    "additional_fee_tzs"?: number,"code"?: string,"created_at"?: string,"description"?: string | null,"display_order"?: number,"id"?: string,"is_active"?: boolean,"name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"cargo_restrictions": {
                  Row: {
                    "cargo_type_id": string,"created_at": string,"description": string,"id": string,"is_active": boolean,"restricted_with_cargo_type_id": string | null,"restriction_details": NonNullable<Json>,"restriction_type": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "cargo_type_id": string,"created_at"?: string,"description": string,"id"?: string,"is_active"?: boolean,"restricted_with_cargo_type_id"?: string | null,"restriction_details"?: NonNullable<Json>,"restriction_type": string,"updated_at"?: string
                  }
                  Update: {
                    "cargo_type_id"?: string,"created_at"?: string,"description"?: string,"id"?: string,"is_active"?: boolean,"restricted_with_cargo_type_id"?: string | null,"restriction_details"?: NonNullable<Json>,"restriction_type"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "cargo_restrictions_cargo_type_id_fkey"
      columns: ["cargo_type_id"]
isOneToOne: false
      referencedRelation: "cargo_types"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "cargo_restrictions_restricted_with_cargo_type_id_fkey"
      columns: ["restricted_with_cargo_type_id"]
isOneToOne: false
      referencedRelation: "cargo_types"
      referencedColumns: ["id"]
    }
                  ]
                },"cargo_types": {
                  Row: {
                    "allowed_vehicle_type_codes": (string)[],"category_id": string | null,"code": string,"country_id": string | null,"created_at": string,"description": string | null,"display_order": number,"icon_url": string | null,"id": string,"is_active": boolean,"max_value_tzs": number | null,"name": string,"prohibited_vehicle_type_codes": (string)[],"requires_declared_value": boolean,"requires_insurance": boolean,"requires_special_handling": boolean,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "allowed_vehicle_type_codes"?: (string)[],"category_id"?: string | null,"code": string,"country_id"?: string | null,"created_at"?: string,"description"?: string | null,"display_order"?: number,"icon_url"?: string | null,"id"?: string,"is_active"?: boolean,"max_value_tzs"?: number | null,"name": string,"prohibited_vehicle_type_codes"?: (string)[],"requires_declared_value"?: boolean,"requires_insurance"?: boolean,"requires_special_handling"?: boolean,"updated_at"?: string
                  }
                  Update: {
                    "allowed_vehicle_type_codes"?: (string)[],"category_id"?: string | null,"code"?: string,"country_id"?: string | null,"created_at"?: string,"description"?: string | null,"display_order"?: number,"icon_url"?: string | null,"id"?: string,"is_active"?: boolean,"max_value_tzs"?: number | null,"name"?: string,"prohibited_vehicle_type_codes"?: (string)[],"requires_declared_value"?: boolean,"requires_insurance"?: boolean,"requires_special_handling"?: boolean,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "cargo_types_category_id_fkey"
      columns: ["category_id"]
isOneToOne: false
      referencedRelation: "cargo_categories"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "cargo_types_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    }
                  ]
                },"chat_attachments": {
                  Row: {
                    "created_at": string,"file_mime_type": string | null,"file_size_bytes": number | null,"id": string,"message_id": number,"storage_path": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"file_mime_type"?: string | null,"file_size_bytes"?: number | null,"id"?: string,"message_id": number,"storage_path": string,"thread_id": string
                  }
                  Update: {
                    "created_at"?: string,"file_mime_type"?: string | null,"file_size_bytes"?: number | null,"id"?: string,"message_id"?: number,"storage_path"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "chat_attachments_thread_id_fkey"
      columns: ["thread_id"]
isOneToOne: false
      referencedRelation: "chat_threads"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "chat_attachments_thread_id_fkey"
      columns: ["thread_id"]
isOneToOne: false
      referencedRelation: "chat_unread_summary"
      referencedColumns: ["thread_id"]
    }
                  ]
                },"chat_messages": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "chat_messages_sender_profile_id_fkey"
      columns: ["sender_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "chat_messages_thread_id_fkey"
      columns: ["thread_id"]
isOneToOne: false
      referencedRelation: "chat_threads"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "chat_messages_thread_id_fkey"
      columns: ["thread_id"]
isOneToOne: false
      referencedRelation: "chat_unread_summary"
      referencedColumns: ["thread_id"]
    }
                  ]
                },"chat_messages_2026_10": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_messages_2026_11": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_messages_2026_12": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_messages_2027_01": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_messages_2027_02": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_messages_2027_03": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_messages_2027_04": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_messages_2027_05": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_messages_2027_06": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_messages_2027_07": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_messages_2027_08": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_messages_2027_09": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_messages_default": {
                  Row: {
                    "body": string | null,"created_at": string,"deleted_at": string | null,"edited_at": string | null,"id": number,"is_deleted": boolean,"is_edited": boolean,"message_type": string,"metadata": NonNullable<Json>,"reply_to_message_id": number | null,"sender_profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id": string,"thread_id": string
                  }
                  Update: {
                    "body"?: string | null,"created_at"?: string,"deleted_at"?: string | null,"edited_at"?: string | null,"id"?: never,"is_deleted"?: boolean,"is_edited"?: boolean,"message_type"?: string,"metadata"?: NonNullable<Json>,"reply_to_message_id"?: number | null,"sender_profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"chat_read_receipts": {
                  Row: {
                    "created_at": string,"id": number,"last_read_at": string,"last_read_message_id": number | null,"profile_id": string,"thread_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: never,"last_read_at"?: string,"last_read_message_id"?: number | null,"profile_id": string,"thread_id": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: never,"last_read_at"?: string,"last_read_message_id"?: number | null,"profile_id"?: string,"thread_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "chat_read_receipts_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "chat_read_receipts_thread_id_fkey"
      columns: ["thread_id"]
isOneToOne: false
      referencedRelation: "chat_threads"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "chat_read_receipts_thread_id_fkey"
      columns: ["thread_id"]
isOneToOne: false
      referencedRelation: "chat_unread_summary"
      referencedColumns: ["thread_id"]
    }
                  ]
                },"chat_threads": {
                  Row: {
                    "archived_at": string | null,"created_at": string,"id": string,"job_id": string,"last_message_at": string | null,"last_message_preview": string | null,"status": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "archived_at"?: string | null,"created_at"?: string,"id"?: string,"job_id": string,"last_message_at"?: string | null,"last_message_preview"?: string | null,"status"?: string,"updated_at"?: string
                  }
                  Update: {
                    "archived_at"?: string | null,"created_at"?: string,"id"?: string,"job_id"?: string,"last_message_at"?: string | null,"last_message_preview"?: string | null,"status"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "chat_threads_job_id_fkey"
      columns: ["job_id"]
isOneToOne: true
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "chat_threads_job_id_fkey"
      columns: ["job_id"]
isOneToOne: true
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "chat_threads_job_id_fkey"
      columns: ["job_id"]
isOneToOne: true
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "chat_threads_job_id_fkey"
      columns: ["job_id"]
isOneToOne: true
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"cities": {
                  Row: {
                    "boundary": unknown,"config": NonNullable<Json>,"country_id": string,"created_at": string,"id": string,"is_active": boolean,"latitude": number | null,"launched_at": string | null,"longitude": number | null,"name": string,"region_id": string,"timezone": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "boundary"?: unknown,"config"?: NonNullable<Json>,"country_id": string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"latitude"?: number | null,"launched_at"?: string | null,"longitude"?: number | null,"name": string,"region_id": string,"timezone": string,"updated_at"?: string
                  }
                  Update: {
                    "boundary"?: unknown,"config"?: NonNullable<Json>,"country_id"?: string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"latitude"?: number | null,"launched_at"?: string | null,"longitude"?: number | null,"name"?: string,"region_id"?: string,"timezone"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "cities_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "cities_region_id_fkey"
      columns: ["region_id"]
isOneToOne: false
      referencedRelation: "regions"
      referencedColumns: ["id"]
    }
                  ]
                },"commission_ledger": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "commission_ledger_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "commission_ledger_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "commission_ledger_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "commission_ledger_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "commission_ledger_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "commission_ledger_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "commission_ledger_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "commission_ledger_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "commission_ledger_rule_id_fkey"
      columns: ["rule_id"]
isOneToOne: false
      referencedRelation: "commission_rules"
      referencedColumns: ["id"]
    }
                  ]
                },"commission_ledger_2026_10": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_ledger_2026_11": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_ledger_2026_12": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_ledger_2027_01": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_ledger_2027_02": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_ledger_2027_03": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_ledger_2027_04": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_ledger_2027_05": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_ledger_2027_06": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_ledger_2027_07": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_ledger_2027_08": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_ledger_2027_09": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_ledger_default": {
                  Row: {
                    "calculated_at": string,"commission_amount": number,"commission_rate": number | null,"created_at": string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id": string,"is_refunded": boolean,"job_id": string,"rule_id": string | null,"withholding_tax_amount": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calculated_at"?: string,"commission_amount": number,"commission_rate"?: number | null,"created_at"?: string,"currency_code": string,"driver_gross_earning": number,"driver_id": string,"driver_net_earning": number,"id"?: string,"is_refunded"?: boolean,"job_id": string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Update: {
                    "calculated_at"?: string,"commission_amount"?: number,"commission_rate"?: number | null,"created_at"?: string,"currency_code"?: string,"driver_gross_earning"?: number,"driver_id"?: string,"driver_net_earning"?: number,"id"?: string,"is_refunded"?: boolean,"job_id"?: string,"rule_id"?: string | null,"withholding_tax_amount"?: number
                  }
                  Relationships: [
                    
                  ]
                },"commission_rules": {
                  Row: {
                    "city_id": string | null,"commission_type": string,"commission_value": number,"country_id": string | null,"created_at": string,"driver_id": string | null,"effective_from": string,"effective_to": string | null,"fleet_id": string | null,"id": string,"is_active": boolean,"max_commission": number | null,"min_commission": number,"priority": number,"updated_at": string,"vehicle_type_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "city_id"?: string | null,"commission_type": string,"commission_value": number,"country_id"?: string | null,"created_at"?: string,"driver_id"?: string | null,"effective_from": string,"effective_to"?: string | null,"fleet_id"?: string | null,"id"?: string,"is_active"?: boolean,"max_commission"?: number | null,"min_commission"?: number,"priority"?: number,"updated_at"?: string,"vehicle_type_id"?: string | null
                  }
                  Update: {
                    "city_id"?: string | null,"commission_type"?: string,"commission_value"?: number,"country_id"?: string | null,"created_at"?: string,"driver_id"?: string | null,"effective_from"?: string,"effective_to"?: string | null,"fleet_id"?: string | null,"id"?: string,"is_active"?: boolean,"max_commission"?: number | null,"min_commission"?: number,"priority"?: number,"updated_at"?: string,"vehicle_type_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "commission_rules_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "commission_rules_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "commission_rules_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "commission_rules_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "commission_rules_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "commission_rules_fleet_id_fkey"
      columns: ["fleet_id"]
isOneToOne: false
      referencedRelation: "active_fleet_roster"
      referencedColumns: ["fleet_id"]
    },{
      foreignKeyName: "commission_rules_fleet_id_fkey"
      columns: ["fleet_id"]
isOneToOne: false
      referencedRelation: "fleets"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "commission_rules_vehicle_type_id_fkey"
      columns: ["vehicle_type_id"]
isOneToOne: false
      referencedRelation: "vehicle_types"
      referencedColumns: ["id"]
    }
                  ]
                },"consent_records": {
                  Row: {
                    "consent_type": string,"consent_version": string,"created_at": string,"granted": boolean,"granted_at": string | null,"id": string,"ip_address": unknown,"profile_id": string,"revoked_at": string | null,"user_agent": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "consent_type": string,"consent_version": string,"created_at"?: string,"granted": boolean,"granted_at"?: string | null,"id"?: string,"ip_address"?: unknown,"profile_id": string,"revoked_at"?: string | null,"user_agent"?: string | null
                  }
                  Update: {
                    "consent_type"?: string,"consent_version"?: string,"created_at"?: string,"granted"?: boolean,"granted_at"?: string | null,"id"?: string,"ip_address"?: unknown,"profile_id"?: string,"revoked_at"?: string | null,"user_agent"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "consent_records_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"countries": {
                  Row: {
                    "config": NonNullable<Json>,"created_at": string,"default_currency_id": string | null,"default_language_id": string | null,"default_timezone": string,"id": string,"is_active": boolean,"iso_code": string,"launched_at": string | null,"name": string,"regulatory_framework": string | null,"tax_registration_required": boolean,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "config"?: NonNullable<Json>,"created_at"?: string,"default_currency_id"?: string | null,"default_language_id"?: string | null,"default_timezone": string,"id"?: string,"is_active"?: boolean,"iso_code": string,"launched_at"?: string | null,"name": string,"regulatory_framework"?: string | null,"tax_registration_required"?: boolean,"updated_at"?: string
                  }
                  Update: {
                    "config"?: NonNullable<Json>,"created_at"?: string,"default_currency_id"?: string | null,"default_language_id"?: string | null,"default_timezone"?: string,"id"?: string,"is_active"?: boolean,"iso_code"?: string,"launched_at"?: string | null,"name"?: string,"regulatory_framework"?: string | null,"tax_registration_required"?: boolean,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "countries_default_currency_fkey"
      columns: ["default_currency_id"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "countries_default_language_fkey"
      columns: ["default_language_id"]
isOneToOne: false
      referencedRelation: "languages"
      referencedColumns: ["id"]
    }
                  ]
                },"currencies": {
                  Row: {
                    "code": string,"created_at": string,"decimal_places": number,"id": string,"is_active": boolean,"name": string,"symbol": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "code": string,"created_at"?: string,"decimal_places"?: number,"id"?: string,"is_active"?: boolean,"name": string,"symbol": string,"updated_at"?: string
                  }
                  Update: {
                    "code"?: string,"created_at"?: string,"decimal_places"?: number,"id"?: string,"is_active"?: boolean,"name"?: string,"symbol"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"customer_metrics": {
                  Row: {
                    "avg_rating_given": number | null,"computed_at": string,"currency_code": string,"customer_id": string,"id": number,"jobs_completed": number,"jobs_created": number,"last_active_at": string | null,"metric_date": string,"total_spent": number
                  }
                  ComputedFields: never
                  Insert: {
                    "avg_rating_given"?: number | null,"computed_at"?: string,"currency_code": string,"customer_id": string,"id"?: never,"jobs_completed"?: number,"jobs_created"?: number,"last_active_at"?: string | null,"metric_date": string,"total_spent"?: number
                  }
                  Update: {
                    "avg_rating_given"?: number | null,"computed_at"?: string,"currency_code"?: string,"customer_id"?: string,"id"?: never,"jobs_completed"?: number,"jobs_created"?: number,"last_active_at"?: string | null,"metric_date"?: string,"total_spent"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "customer_metrics_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "customer_metrics_customer_id_fkey"
      columns: ["customer_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"customers": {
                  Row: {
                    "created_at": string,"default_address_id": string | null,"flagged_reason": string | null,"id": string,"is_flagged": boolean,"preferred_payment_method_id": string | null,"rating": number | null,"total_jobs": number,"total_spent": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"default_address_id"?: string | null,"flagged_reason"?: string | null,"id": string,"is_flagged"?: boolean,"preferred_payment_method_id"?: string | null,"rating"?: number | null,"total_jobs"?: number,"total_spent"?: number,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"default_address_id"?: string | null,"flagged_reason"?: string | null,"id"?: string,"is_flagged"?: boolean,"preferred_payment_method_id"?: string | null,"rating"?: number | null,"total_jobs"?: number,"total_spent"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "customers_default_address_id_fkey"
      columns: ["default_address_id"]
isOneToOne: false
      referencedRelation: "addresses"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "customers_id_fkey"
      columns: ["id"]
isOneToOne: true
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"daily_metrics": {
                  Row: {
                    "active_customers": number,"active_drivers": number,"avg_acceptance_rate": number | null,"avg_cancellation_rate": number | null,"avg_completion_minutes": number | null,"avg_rating": number | null,"city_id": string | null,"computed_at": string,"country_id": string,"created_at": string,"currency_code": string,"gross_booking_value": number,"id": number,"jobs_cancelled": number,"jobs_completed": number,"jobs_created": number,"metric_date": string,"net_revenue": number,"new_customers": number,"new_drivers": number
                  }
                  ComputedFields: never
                  Insert: {
                    "active_customers"?: number,"active_drivers"?: number,"avg_acceptance_rate"?: number | null,"avg_cancellation_rate"?: number | null,"avg_completion_minutes"?: number | null,"avg_rating"?: number | null,"city_id"?: string | null,"computed_at"?: string,"country_id": string,"created_at"?: string,"currency_code": string,"gross_booking_value"?: number,"id"?: never,"jobs_cancelled"?: number,"jobs_completed"?: number,"jobs_created"?: number,"metric_date": string,"net_revenue"?: number,"new_customers"?: number,"new_drivers"?: number
                  }
                  Update: {
                    "active_customers"?: number,"active_drivers"?: number,"avg_acceptance_rate"?: number | null,"avg_cancellation_rate"?: number | null,"avg_completion_minutes"?: number | null,"avg_rating"?: number | null,"city_id"?: string | null,"computed_at"?: string,"country_id"?: string,"created_at"?: string,"currency_code"?: string,"gross_booking_value"?: number,"id"?: never,"jobs_cancelled"?: number,"jobs_completed"?: number,"jobs_created"?: number,"metric_date"?: string,"net_revenue"?: number,"new_customers"?: number,"new_drivers"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "daily_metrics_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "daily_metrics_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "daily_metrics_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    }
                  ]
                },"data_access_log": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    {
      foreignKeyName: "data_access_log_accessor_profile_id_fkey"
      columns: ["accessor_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "data_access_log_target_profile_id_fkey"
      columns: ["target_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"data_access_log_2026_10": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2026_11": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2026_12": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2027_01": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2027_02": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2027_03": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2027_04": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2027_05": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2027_06": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2027_07": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2027_08": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2027_09": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2027_10": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2027_11": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2027_12": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2028_01": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2028_02": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2028_03": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2028_04": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2028_05": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2028_06": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2028_07": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2028_08": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2028_09": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2028_10": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2028_11": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2028_12": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2029_01": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2029_02": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2029_03": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2029_04": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2029_05": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2029_06": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2029_07": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2029_08": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2029_09": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2029_10": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2029_11": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2029_12": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2030_01": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2030_02": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2030_03": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2030_04": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2030_05": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2030_06": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2030_07": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2030_08": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2030_09": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2030_10": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2030_11": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2030_12": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2031_01": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2031_02": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2031_03": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2031_04": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2031_05": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2031_06": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2031_07": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2031_08": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2031_09": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2031_10": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2031_11": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2031_12": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2032_01": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2032_02": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2032_03": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2032_04": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2032_05": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2032_06": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2032_07": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2032_08": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2032_09": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2032_10": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2032_11": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2032_12": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2033_01": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2033_02": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2033_03": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2033_04": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2033_05": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2033_06": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2033_07": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2033_08": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_2033_09": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_access_log_default": {
                  Row: {
                    "access_type": string,"accessor_ip": unknown,"accessor_profile_id": string | null,"accessor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string,"id": number,"purpose": string | null,"target_field": string | null,"target_id": string | null,"target_profile_id": string | null,"target_table": string,"was_authorized": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "access_type": string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table": string,"was_authorized"?: boolean
                  }
                  Update: {
                    "access_type"?: string,"accessor_ip"?: unknown,"accessor_profile_id"?: string | null,"accessor_role"?: Database["public"]['Enums']["user_role"] | null,"created_at"?: string,"id"?: never,"purpose"?: string | null,"target_field"?: string | null,"target_id"?: string | null,"target_profile_id"?: string | null,"target_table"?: string,"was_authorized"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"data_subject_requests": {
                  Row: {
                    "assigned_to": string | null,"completed_at": string | null,"created_at": string,"delivered_file_path": string | null,"id": string,"notes": string | null,"reason": string | null,"rejected_reason": string | null,"request_number": string,"request_type": string,"requested_at": string,"requester_profile_id": string,"status": string,"updated_at": string,"verified_at": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "assigned_to"?: string | null,"completed_at"?: string | null,"created_at"?: string,"delivered_file_path"?: string | null,"id"?: string,"notes"?: string | null,"reason"?: string | null,"rejected_reason"?: string | null,"request_number": string,"request_type": string,"requested_at"?: string,"requester_profile_id": string,"status"?: string,"updated_at"?: string,"verified_at"?: string | null
                  }
                  Update: {
                    "assigned_to"?: string | null,"completed_at"?: string | null,"created_at"?: string,"delivered_file_path"?: string | null,"id"?: string,"notes"?: string | null,"reason"?: string | null,"rejected_reason"?: string | null,"request_number"?: string,"request_type"?: string,"requested_at"?: string,"requester_profile_id"?: string,"status"?: string,"updated_at"?: string,"verified_at"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "data_subject_requests_assigned_to_fkey"
      columns: ["assigned_to"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "data_subject_requests_requester_profile_id_fkey"
      columns: ["requester_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"demand_snapshots": {
                  Row: {
                    "active_drivers": number,"active_job_requests": number,"avg_wait_seconds": number | null,"computed_at": string,"id": number,"pending_offers": number,"service_zone_id": string,"snapshot_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "active_drivers"?: number,"active_job_requests"?: number,"avg_wait_seconds"?: number | null,"computed_at"?: string,"id"?: never,"pending_offers"?: number,"service_zone_id": string,"snapshot_at": string
                  }
                  Update: {
                    "active_drivers"?: number,"active_job_requests"?: number,"avg_wait_seconds"?: number | null,"computed_at"?: string,"id"?: never,"pending_offers"?: number,"service_zone_id"?: string,"snapshot_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "demand_snapshots_service_zone_id_fkey"
      columns: ["service_zone_id"]
isOneToOne: false
      referencedRelation: "service_zones"
      referencedColumns: ["id"]
    }
                  ]
                },"demand_snapshots_2026_10": {
                  Row: {
                    "active_drivers": number,"active_job_requests": number,"avg_wait_seconds": number | null,"computed_at": string,"id": number,"pending_offers": number,"service_zone_id": string,"snapshot_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "active_drivers"?: number,"active_job_requests"?: number,"avg_wait_seconds"?: number | null,"computed_at"?: string,"id"?: never,"pending_offers"?: number,"service_zone_id": string,"snapshot_at": string
                  }
                  Update: {
                    "active_drivers"?: number,"active_job_requests"?: number,"avg_wait_seconds"?: number | null,"computed_at"?: string,"id"?: never,"pending_offers"?: number,"service_zone_id"?: string,"snapshot_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"demand_snapshots_2026_11": {
                  Row: {
                    "active_drivers": number,"active_job_requests": number,"avg_wait_seconds": number | null,"computed_at": string,"id": number,"pending_offers": number,"service_zone_id": string,"snapshot_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "active_drivers"?: number,"active_job_requests"?: number,"avg_wait_seconds"?: number | null,"computed_at"?: string,"id"?: never,"pending_offers"?: number,"service_zone_id": string,"snapshot_at": string
                  }
                  Update: {
                    "active_drivers"?: number,"active_job_requests"?: number,"avg_wait_seconds"?: number | null,"computed_at"?: string,"id"?: never,"pending_offers"?: number,"service_zone_id"?: string,"snapshot_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"demand_snapshots_2026_12": {
                  Row: {
                    "active_drivers": number,"active_job_requests": number,"avg_wait_seconds": number | null,"computed_at": string,"id": number,"pending_offers": number,"service_zone_id": string,"snapshot_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "active_drivers"?: number,"active_job_requests"?: number,"avg_wait_seconds"?: number | null,"computed_at"?: string,"id"?: never,"pending_offers"?: number,"service_zone_id": string,"snapshot_at": string
                  }
                  Update: {
                    "active_drivers"?: number,"active_job_requests"?: number,"avg_wait_seconds"?: number | null,"computed_at"?: string,"id"?: never,"pending_offers"?: number,"service_zone_id"?: string,"snapshot_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"demand_snapshots_default": {
                  Row: {
                    "active_drivers": number,"active_job_requests": number,"avg_wait_seconds": number | null,"computed_at": string,"id": number,"pending_offers": number,"service_zone_id": string,"snapshot_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "active_drivers"?: number,"active_job_requests"?: number,"avg_wait_seconds"?: number | null,"computed_at"?: string,"id"?: never,"pending_offers"?: number,"service_zone_id": string,"snapshot_at": string
                  }
                  Update: {
                    "active_drivers"?: number,"active_job_requests"?: number,"avg_wait_seconds"?: number | null,"computed_at"?: string,"id"?: never,"pending_offers"?: number,"service_zone_id"?: string,"snapshot_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"dispatch_rules": {
                  Row: {
                    "city_id": string | null,"country_id": string | null,"created_at": string,"id": string,"is_active": boolean,"max_concurrent_offers": number,"max_search_radius_km": number,"min_driver_rating": number | null,"minimum_acceptance_rate": number | null,"offer_timeout_seconds": number,"reassign_after_seconds": number,"updated_at": string,"vehicle_type_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "city_id"?: string | null,"country_id"?: string | null,"created_at"?: string,"id"?: string,"is_active"?: boolean,"max_concurrent_offers"?: number,"max_search_radius_km"?: number,"min_driver_rating"?: number | null,"minimum_acceptance_rate"?: number | null,"offer_timeout_seconds"?: number,"reassign_after_seconds"?: number,"updated_at"?: string,"vehicle_type_id"?: string | null
                  }
                  Update: {
                    "city_id"?: string | null,"country_id"?: string | null,"created_at"?: string,"id"?: string,"is_active"?: boolean,"max_concurrent_offers"?: number,"max_search_radius_km"?: number,"min_driver_rating"?: number | null,"minimum_acceptance_rate"?: number | null,"offer_timeout_seconds"?: number,"reassign_after_seconds"?: number,"updated_at"?: string,"vehicle_type_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "dispatch_rules_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "dispatch_rules_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "dispatch_rules_vehicle_type_id_fkey"
      columns: ["vehicle_type_id"]
isOneToOne: false
      referencedRelation: "vehicle_types"
      referencedColumns: ["id"]
    }
                  ]
                },"dispute_attachments": {
                  Row: {
                    "created_at": string,"dispute_id": string,"file_mime_type": string | null,"file_size_bytes": number | null,"id": string,"message_id": string | null,"storage_path": string,"uploaded_by": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"dispute_id": string,"file_mime_type"?: string | null,"file_size_bytes"?: number | null,"id"?: string,"message_id"?: string | null,"storage_path": string,"uploaded_by": string
                  }
                  Update: {
                    "created_at"?: string,"dispute_id"?: string,"file_mime_type"?: string | null,"file_size_bytes"?: number | null,"id"?: string,"message_id"?: string | null,"storage_path"?: string,"uploaded_by"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "dispute_attachments_dispute_id_fkey"
      columns: ["dispute_id"]
isOneToOne: false
      referencedRelation: "dispute_summary"
      referencedColumns: ["dispute_id"]
    },{
      foreignKeyName: "dispute_attachments_dispute_id_fkey"
      columns: ["dispute_id"]
isOneToOne: false
      referencedRelation: "disputes"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "dispute_attachments_message_id_fkey"
      columns: ["message_id"]
isOneToOne: false
      referencedRelation: "dispute_messages"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "dispute_attachments_uploaded_by_fkey"
      columns: ["uploaded_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"dispute_messages": {
                  Row: {
                    "created_at": string,"dispute_id": string,"id": string,"is_internal_note": boolean,"message": string,"sender_profile_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"dispute_id": string,"id"?: string,"is_internal_note"?: boolean,"message": string,"sender_profile_id": string
                  }
                  Update: {
                    "created_at"?: string,"dispute_id"?: string,"id"?: string,"is_internal_note"?: boolean,"message"?: string,"sender_profile_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "dispute_messages_dispute_id_fkey"
      columns: ["dispute_id"]
isOneToOne: false
      referencedRelation: "dispute_summary"
      referencedColumns: ["dispute_id"]
    },{
      foreignKeyName: "dispute_messages_dispute_id_fkey"
      columns: ["dispute_id"]
isOneToOne: false
      referencedRelation: "disputes"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "dispute_messages_sender_profile_id_fkey"
      columns: ["sender_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"dispute_resolutions": {
                  Row: {
                    "action": string,"created_at": string,"details": NonNullable<Json>,"dispute_id": string,"from_state": string | null,"id": number,"resolver_id": string,"to_state": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "action": string,"created_at"?: string,"details"?: NonNullable<Json>,"dispute_id": string,"from_state"?: string | null,"id"?: never,"resolver_id": string,"to_state"?: string | null
                  }
                  Update: {
                    "action"?: string,"created_at"?: string,"details"?: NonNullable<Json>,"dispute_id"?: string,"from_state"?: string | null,"id"?: never,"resolver_id"?: string,"to_state"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "dispute_resolutions_dispute_id_fkey"
      columns: ["dispute_id"]
isOneToOne: false
      referencedRelation: "dispute_summary"
      referencedColumns: ["dispute_id"]
    },{
      foreignKeyName: "dispute_resolutions_dispute_id_fkey"
      columns: ["dispute_id"]
isOneToOne: false
      referencedRelation: "disputes"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "dispute_resolutions_resolver_id_fkey"
      columns: ["resolver_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"disputes": {
                  Row: {
                    "compensation_amount": number | null,"created_at": string,"currency_code": string | null,"dispute_type": string,"id": string,"job_id": string,"priority": string,"raised_by": string,"raised_by_role": Database["public"]['Enums']["user_role"],"requested_resolution": string | null,"resolution_notes": string | null,"resolved_at": string | null,"resolved_by": string | null,"sla_due_at": string | null,"status": string,"summary": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "compensation_amount"?: number | null,"created_at"?: string,"currency_code"?: string | null,"dispute_type": string,"id"?: string,"job_id": string,"priority"?: string,"raised_by": string,"raised_by_role": Database["public"]['Enums']["user_role"],"requested_resolution"?: string | null,"resolution_notes"?: string | null,"resolved_at"?: string | null,"resolved_by"?: string | null,"sla_due_at"?: string | null,"status"?: string,"summary": string,"updated_at"?: string
                  }
                  Update: {
                    "compensation_amount"?: number | null,"created_at"?: string,"currency_code"?: string | null,"dispute_type"?: string,"id"?: string,"job_id"?: string,"priority"?: string,"raised_by"?: string,"raised_by_role"?: Database["public"]['Enums']["user_role"],"requested_resolution"?: string | null,"resolution_notes"?: string | null,"resolved_at"?: string | null,"resolved_by"?: string | null,"sla_due_at"?: string | null,"status"?: string,"summary"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "disputes_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "disputes_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "disputes_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "disputes_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "disputes_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "disputes_raised_by_fkey"
      columns: ["raised_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "disputes_resolved_by_fkey"
      columns: ["resolved_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"document_expiry_reminders": {
                  Row: {
                    "created_at": string,"delivery_channel": string | null,"delivery_status": string | null,"driver_document_id": string | null,"id": string,"reminder_type": string,"scheduled_for": string,"sent_at": string | null,"vehicle_document_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"delivery_channel"?: string | null,"delivery_status"?: string | null,"driver_document_id"?: string | null,"id"?: string,"reminder_type": string,"scheduled_for": string,"sent_at"?: string | null,"vehicle_document_id"?: string | null
                  }
                  Update: {
                    "created_at"?: string,"delivery_channel"?: string | null,"delivery_status"?: string | null,"driver_document_id"?: string | null,"id"?: string,"reminder_type"?: string,"scheduled_for"?: string,"sent_at"?: string | null,"vehicle_document_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "document_expiry_reminders_driver_document_id_fkey"
      columns: ["driver_document_id"]
isOneToOne: false
      referencedRelation: "driver_documents"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "document_expiry_reminders_vehicle_document_id_fkey"
      columns: ["vehicle_document_id"]
isOneToOne: false
      referencedRelation: "vehicle_documents"
      referencedColumns: ["id"]
    }
                  ]
                },"document_types": {
                  Row: {
                    "applies_to": string,"code": string,"country_id": string | null,"created_at": string,"description": string | null,"has_expiry": boolean,"id": string,"is_active": boolean,"is_required": boolean,"name": string,"updated_at": string,"validity_days": number | null,"verification_sla_hours": number
                  }
                  ComputedFields: never
                  Insert: {
                    "applies_to": string,"code": string,"country_id"?: string | null,"created_at"?: string,"description"?: string | null,"has_expiry"?: boolean,"id"?: string,"is_active"?: boolean,"is_required"?: boolean,"name": string,"updated_at"?: string,"validity_days"?: number | null,"verification_sla_hours"?: number
                  }
                  Update: {
                    "applies_to"?: string,"code"?: string,"country_id"?: string | null,"created_at"?: string,"description"?: string | null,"has_expiry"?: boolean,"id"?: string,"is_active"?: boolean,"is_required"?: boolean,"name"?: string,"updated_at"?: string,"validity_days"?: number | null,"verification_sla_hours"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "document_types_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    }
                  ]
                },"driver_acceptance_stats": {
                  Row: {
                    "acceptance_rate": number | null,"avg_response_seconds": number | null,"driver_id": string,"offers_accepted": number,"offers_declined": number,"offers_expired": number,"offers_received": number,"updated_at": string,"window_end": string,"window_start": string
                  }
                  ComputedFields: never
                  Insert: {
                    "acceptance_rate"?: number | null,"avg_response_seconds"?: number | null,"driver_id": string,"offers_accepted"?: number,"offers_declined"?: number,"offers_expired"?: number,"offers_received"?: number,"updated_at"?: string,"window_end": string,"window_start": string
                  }
                  Update: {
                    "acceptance_rate"?: number | null,"avg_response_seconds"?: number | null,"driver_id"?: string,"offers_accepted"?: number,"offers_declined"?: number,"offers_expired"?: number,"offers_received"?: number,"updated_at"?: string,"window_end"?: string,"window_start"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "driver_acceptance_stats_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: true
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_acceptance_stats_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: true
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_acceptance_stats_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: true
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    }
                  ]
                },"driver_documents": {
                  Row: {
                    "created_at": string,"document_number": string | null,"document_type_id": string,"driver_id": string,"expires_at": string | null,"file_mime_type": string | null,"file_path": string,"file_size_bytes": number | null,"id": string,"is_current": boolean,"issued_at": string | null,"rejection_reason": string | null,"superseded_by": string | null,"updated_at": string,"verification_status": Database["public"]['Enums']["driver_verification_status"],"verified_at": string | null,"verified_by": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"document_number"?: string | null,"document_type_id": string,"driver_id": string,"expires_at"?: string | null,"file_mime_type"?: string | null,"file_path": string,"file_size_bytes"?: number | null,"id"?: string,"is_current"?: boolean,"issued_at"?: string | null,"rejection_reason"?: string | null,"superseded_by"?: string | null,"updated_at"?: string,"verification_status"?: Database["public"]['Enums']["driver_verification_status"],"verified_at"?: string | null,"verified_by"?: string | null
                  }
                  Update: {
                    "created_at"?: string,"document_number"?: string | null,"document_type_id"?: string,"driver_id"?: string,"expires_at"?: string | null,"file_mime_type"?: string | null,"file_path"?: string,"file_size_bytes"?: number | null,"id"?: string,"is_current"?: boolean,"issued_at"?: string | null,"rejection_reason"?: string | null,"superseded_by"?: string | null,"updated_at"?: string,"verification_status"?: Database["public"]['Enums']["driver_verification_status"],"verified_at"?: string | null,"verified_by"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "driver_documents_document_type_id_fkey"
      columns: ["document_type_id"]
isOneToOne: false
      referencedRelation: "document_types"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "driver_documents_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_documents_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_documents_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "driver_documents_superseded_by_fkey"
      columns: ["superseded_by"]
isOneToOne: false
      referencedRelation: "driver_documents"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "driver_documents_verified_by_fkey"
      columns: ["verified_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"driver_locations": {
                  Row: {
                    "accuracy_m": number | null,"created_at": string,"driver_id": string,"heading_degrees": number | null,"id": number,"job_id": string | null,"location": unknown,"recorded_at": string,"speed_kmh": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id": string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location": unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Update: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id"?: string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location"?: unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "driver_locations_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_locations_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_locations_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "driver_locations_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "driver_locations_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "driver_locations_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "driver_locations_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"driver_locations_2026_10": {
                  Row: {
                    "accuracy_m": number | null,"created_at": string,"driver_id": string,"heading_degrees": number | null,"id": number,"job_id": string | null,"location": unknown,"recorded_at": string,"speed_kmh": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id": string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location": unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Update: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id"?: string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location"?: unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Relationships: [
                    
                  ]
                },"driver_locations_2026_11": {
                  Row: {
                    "accuracy_m": number | null,"created_at": string,"driver_id": string,"heading_degrees": number | null,"id": number,"job_id": string | null,"location": unknown,"recorded_at": string,"speed_kmh": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id": string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location": unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Update: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id"?: string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location"?: unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Relationships: [
                    
                  ]
                },"driver_locations_2026_12": {
                  Row: {
                    "accuracy_m": number | null,"created_at": string,"driver_id": string,"heading_degrees": number | null,"id": number,"job_id": string | null,"location": unknown,"recorded_at": string,"speed_kmh": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id": string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location": unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Update: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id"?: string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location"?: unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Relationships: [
                    
                  ]
                },"driver_locations_2027_01": {
                  Row: {
                    "accuracy_m": number | null,"created_at": string,"driver_id": string,"heading_degrees": number | null,"id": number,"job_id": string | null,"location": unknown,"recorded_at": string,"speed_kmh": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id": string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location": unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Update: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id"?: string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location"?: unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Relationships: [
                    
                  ]
                },"driver_locations_2027_02": {
                  Row: {
                    "accuracy_m": number | null,"created_at": string,"driver_id": string,"heading_degrees": number | null,"id": number,"job_id": string | null,"location": unknown,"recorded_at": string,"speed_kmh": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id": string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location": unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Update: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id"?: string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location"?: unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Relationships: [
                    
                  ]
                },"driver_locations_2027_03": {
                  Row: {
                    "accuracy_m": number | null,"created_at": string,"driver_id": string,"heading_degrees": number | null,"id": number,"job_id": string | null,"location": unknown,"recorded_at": string,"speed_kmh": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id": string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location": unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Update: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id"?: string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location"?: unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Relationships: [
                    
                  ]
                },"driver_locations_default": {
                  Row: {
                    "accuracy_m": number | null,"created_at": string,"driver_id": string,"heading_degrees": number | null,"id": number,"job_id": string | null,"location": unknown,"recorded_at": string,"speed_kmh": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id": string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location": unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Update: {
                    "accuracy_m"?: number | null,"created_at"?: string,"driver_id"?: string,"heading_degrees"?: number | null,"id"?: never,"job_id"?: string | null,"location"?: unknown,"recorded_at"?: string,"speed_kmh"?: number | null
                  }
                  Relationships: [
                    
                  ]
                },"driver_metrics": {
                  Row: {
                    "acceptance_rate": number | null,"avg_distance_km": number | null,"avg_rating": number | null,"computed_at": string,"currency_code": string,"driver_id": string,"earnings_gross": number,"earnings_net": number,"hours_online": number | null,"id": number,"metric_date": string,"on_time_rate": number | null,"trips_completed": number
                  }
                  ComputedFields: never
                  Insert: {
                    "acceptance_rate"?: number | null,"avg_distance_km"?: number | null,"avg_rating"?: number | null,"computed_at"?: string,"currency_code": string,"driver_id": string,"earnings_gross"?: number,"earnings_net"?: number,"hours_online"?: number | null,"id"?: never,"metric_date": string,"on_time_rate"?: number | null,"trips_completed"?: number
                  }
                  Update: {
                    "acceptance_rate"?: number | null,"avg_distance_km"?: number | null,"avg_rating"?: number | null,"computed_at"?: string,"currency_code"?: string,"driver_id"?: string,"earnings_gross"?: number,"earnings_net"?: number,"hours_online"?: number | null,"id"?: never,"metric_date"?: string,"on_time_rate"?: number | null,"trips_completed"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "driver_metrics_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "driver_metrics_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_metrics_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_metrics_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    }
                  ]
                },"driver_operating_zones": {
                  Row: {
                    "created_at": string,"driver_id": string,"id": string,"is_primary": boolean,"service_zone_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"driver_id": string,"id"?: string,"is_primary"?: boolean,"service_zone_id": string
                  }
                  Update: {
                    "created_at"?: string,"driver_id"?: string,"id"?: string,"is_primary"?: boolean,"service_zone_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "driver_operating_zones_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_operating_zones_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_operating_zones_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "driver_operating_zones_service_zone_id_fkey"
      columns: ["service_zone_id"]
isOneToOne: false
      referencedRelation: "service_zones"
      referencedColumns: ["id"]
    }
                  ]
                },"driver_service_hours": {
                  Row: {
                    "created_at": string,"day_of_week": number,"driver_id": string,"end_time": string,"id": string,"is_active": boolean,"start_time": string,"timezone": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"day_of_week": number,"driver_id": string,"end_time": string,"id"?: string,"is_active"?: boolean,"start_time": string,"timezone": string
                  }
                  Update: {
                    "created_at"?: string,"day_of_week"?: number,"driver_id"?: string,"end_time"?: string,"id"?: string,"is_active"?: boolean,"start_time"?: string,"timezone"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "driver_service_hours_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_service_hours_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_service_hours_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    }
                  ]
                },"driver_status_history": {
                  Row: {
                    "changed_by": string | null,"created_at": string,"driver_id": string,"field_changed": string,"id": number,"new_value": string | null,"old_value": string | null,"reason": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "changed_by"?: string | null,"created_at"?: string,"driver_id": string,"field_changed": string,"id"?: never,"new_value"?: string | null,"old_value"?: string | null,"reason"?: string | null
                  }
                  Update: {
                    "changed_by"?: string | null,"created_at"?: string,"driver_id"?: string,"field_changed"?: string,"id"?: never,"new_value"?: string | null,"old_value"?: string | null,"reason"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "driver_status_history_changed_by_fkey"
      columns: ["changed_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "driver_status_history_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_status_history_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "driver_status_history_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    }
                  ]
                },"drivers": {
                  Row: {
                    "country_id": string,"created_at": string,"current_fleet_id": string | null,"current_location": unknown,"current_vehicle_id": string | null,"home_city_id": string | null,"id": string,"is_available": boolean,"licence_country_id": string | null,"licence_expiry": string | null,"licence_number": string | null,"location_updated_at": string | null,"rating": number,"re_verification_due_at": string | null,"risk_tier": Database["public"]['Enums']["driver_risk_tier"],"total_earnings": number,"total_trips": number,"updated_at": string,"verification_status": Database["public"]['Enums']["driver_verification_status"],"verified_at": string | null,"verified_by": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "country_id": string,"created_at"?: string,"current_fleet_id"?: string | null,"current_location"?: unknown,"current_vehicle_id"?: string | null,"home_city_id"?: string | null,"id": string,"is_available"?: boolean,"licence_country_id"?: string | null,"licence_expiry"?: string | null,"licence_number"?: string | null,"location_updated_at"?: string | null,"rating"?: number,"re_verification_due_at"?: string | null,"risk_tier"?: Database["public"]['Enums']["driver_risk_tier"],"total_earnings"?: number,"total_trips"?: number,"updated_at"?: string,"verification_status"?: Database["public"]['Enums']["driver_verification_status"],"verified_at"?: string | null,"verified_by"?: string | null
                  }
                  Update: {
                    "country_id"?: string,"created_at"?: string,"current_fleet_id"?: string | null,"current_location"?: unknown,"current_vehicle_id"?: string | null,"home_city_id"?: string | null,"id"?: string,"is_available"?: boolean,"licence_country_id"?: string | null,"licence_expiry"?: string | null,"licence_number"?: string | null,"location_updated_at"?: string | null,"rating"?: number,"re_verification_due_at"?: string | null,"risk_tier"?: Database["public"]['Enums']["driver_risk_tier"],"total_earnings"?: number,"total_trips"?: number,"updated_at"?: string,"verification_status"?: Database["public"]['Enums']["driver_verification_status"],"verified_at"?: string | null,"verified_by"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "drivers_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "drivers_current_fleet_id_fkey"
      columns: ["current_fleet_id"]
isOneToOne: false
      referencedRelation: "active_fleet_roster"
      referencedColumns: ["fleet_id"]
    },{
      foreignKeyName: "drivers_current_fleet_id_fkey"
      columns: ["current_fleet_id"]
isOneToOne: false
      referencedRelation: "fleets"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "drivers_current_vehicle_id_fkey"
      columns: ["current_vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_public_view"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "drivers_current_vehicle_id_fkey"
      columns: ["current_vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_verification_summary"
      referencedColumns: ["vehicle_id"]
    },{
      foreignKeyName: "drivers_current_vehicle_id_fkey"
      columns: ["current_vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "drivers_home_city_id_fkey"
      columns: ["home_city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "drivers_id_fkey"
      columns: ["id"]
isOneToOne: true
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "drivers_licence_country_id_fkey"
      columns: ["licence_country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "drivers_verified_by_fkey"
      columns: ["verified_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"emergency_contacts": {
                  Row: {
                    "created_at": string,"id": string,"is_primary": boolean,"name": string,"notify_on_sos": boolean,"notify_on_trip_start": boolean,"phone": string,"profile_id": string,"relationship": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"is_primary"?: boolean,"name": string,"notify_on_sos"?: boolean,"notify_on_trip_start"?: boolean,"phone": string,"profile_id": string,"relationship"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"is_primary"?: boolean,"name"?: string,"notify_on_sos"?: boolean,"notify_on_trip_start"?: boolean,"phone"?: string,"profile_id"?: string,"relationship"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "emergency_contacts_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"exchange_rates": {
                  Row: {
                    "created_at": string,"effective_from": string,"effective_to": string | null,"from_currency_id": string,"id": string,"rate": number,"source": string,"to_currency_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"effective_from": string,"effective_to"?: string | null,"from_currency_id": string,"id"?: string,"rate": number,"source": string,"to_currency_id": string
                  }
                  Update: {
                    "created_at"?: string,"effective_from"?: string,"effective_to"?: string | null,"from_currency_id"?: string,"id"?: string,"rate"?: number,"source"?: string,"to_currency_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "exchange_rates_from_currency_id_fkey"
      columns: ["from_currency_id"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "exchange_rates_to_currency_id_fkey"
      columns: ["to_currency_id"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["id"]
    }
                  ]
                },"feature_flags": {
                  Row: {
                    "city_id": string | null,"country_id": string | null,"created_at": string,"description": string | null,"flag_key": string,"id": string,"is_enabled": boolean,"profile_id": string | null,"rollout_percentage": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "city_id"?: string | null,"country_id"?: string | null,"created_at"?: string,"description"?: string | null,"flag_key": string,"id"?: string,"is_enabled"?: boolean,"profile_id"?: string | null,"rollout_percentage"?: number,"updated_at"?: string
                  }
                  Update: {
                    "city_id"?: string | null,"country_id"?: string | null,"created_at"?: string,"description"?: string | null,"flag_key"?: string,"id"?: string,"is_enabled"?: boolean,"profile_id"?: string | null,"rollout_percentage"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "feature_flags_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "feature_flags_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "feature_flags_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"fleet_billing_events": {
                  Row: {
                    "accrued_at": string,"commission_calculated_at": string,"commission_ledger_id": string,"created_at": string,"currency_code": string,"fleet_commission_amount": number,"fleet_commission_rate": number,"fleet_id": string,"id": number,"job_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "accrued_at"?: string,"commission_calculated_at": string,"commission_ledger_id": string,"created_at"?: string,"currency_code": string,"fleet_commission_amount": number,"fleet_commission_rate": number,"fleet_id": string,"id"?: never,"job_id": string
                  }
                  Update: {
                    "accrued_at"?: string,"commission_calculated_at"?: string,"commission_ledger_id"?: string,"created_at"?: string,"currency_code"?: string,"fleet_commission_amount"?: number,"fleet_commission_rate"?: number,"fleet_id"?: string,"id"?: never,"job_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "fleet_billing_events_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "fleet_billing_events_fleet_id_fkey"
      columns: ["fleet_id"]
isOneToOne: false
      referencedRelation: "active_fleet_roster"
      referencedColumns: ["fleet_id"]
    },{
      foreignKeyName: "fleet_billing_events_fleet_id_fkey"
      columns: ["fleet_id"]
isOneToOne: false
      referencedRelation: "fleets"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "fleet_billing_events_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "fleet_billing_events_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "fleet_billing_events_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "fleet_billing_events_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "fleet_billing_events_ledger_fkey"
      columns: ["commission_ledger_id","commission_calculated_at"]
isOneToOne: false
      referencedRelation: "commission_ledger"
      referencedColumns: ["id","calculated_at"]
    }
                  ]
                },"fleet_members": {
                  Row: {
                    "created_at": string,"driver_id": string,"fleet_id": string,"id": string,"is_active": boolean,"joined_at": string,"left_at": string | null,"role": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"driver_id": string,"fleet_id": string,"id"?: string,"is_active"?: boolean,"joined_at"?: string,"left_at"?: string | null,"role": string,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"driver_id"?: string,"fleet_id"?: string,"id"?: string,"is_active"?: boolean,"joined_at"?: string,"left_at"?: string | null,"role"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "fleet_members_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "fleet_members_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "fleet_members_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "fleet_members_fleet_id_fkey"
      columns: ["fleet_id"]
isOneToOne: false
      referencedRelation: "active_fleet_roster"
      referencedColumns: ["fleet_id"]
    },{
      foreignKeyName: "fleet_members_fleet_id_fkey"
      columns: ["fleet_id"]
isOneToOne: false
      referencedRelation: "fleets"
      referencedColumns: ["id"]
    }
                  ]
                },"fleet_reports": {
                  Row: {
                    "created_at": string,"file_path": string | null,"fleet_id": string,"generated_at": string,"generated_by": string | null,"id": string,"metadata": NonNullable<Json>,"period_end": string,"period_start": string,"report_type": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"file_path"?: string | null,"fleet_id": string,"generated_at"?: string,"generated_by"?: string | null,"id"?: string,"metadata"?: NonNullable<Json>,"period_end": string,"period_start": string,"report_type": string
                  }
                  Update: {
                    "created_at"?: string,"file_path"?: string | null,"fleet_id"?: string,"generated_at"?: string,"generated_by"?: string | null,"id"?: string,"metadata"?: NonNullable<Json>,"period_end"?: string,"period_start"?: string,"report_type"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "fleet_reports_fleet_id_fkey"
      columns: ["fleet_id"]
isOneToOne: false
      referencedRelation: "active_fleet_roster"
      referencedColumns: ["fleet_id"]
    },{
      foreignKeyName: "fleet_reports_fleet_id_fkey"
      columns: ["fleet_id"]
isOneToOne: false
      referencedRelation: "fleets"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "fleet_reports_generated_by_fkey"
      columns: ["generated_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"fleet_vehicles": {
                  Row: {
                    "assigned_at": string,"created_at": string,"fleet_id": string,"id": string,"is_active": boolean,"unassigned_at": string | null,"updated_at": string,"vehicle_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "assigned_at"?: string,"created_at"?: string,"fleet_id": string,"id"?: string,"is_active"?: boolean,"unassigned_at"?: string | null,"updated_at"?: string,"vehicle_id": string
                  }
                  Update: {
                    "assigned_at"?: string,"created_at"?: string,"fleet_id"?: string,"id"?: string,"is_active"?: boolean,"unassigned_at"?: string | null,"updated_at"?: string,"vehicle_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "fleet_vehicles_fleet_id_fkey"
      columns: ["fleet_id"]
isOneToOne: false
      referencedRelation: "active_fleet_roster"
      referencedColumns: ["fleet_id"]
    },{
      foreignKeyName: "fleet_vehicles_fleet_id_fkey"
      columns: ["fleet_id"]
isOneToOne: false
      referencedRelation: "fleets"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "fleet_vehicles_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_public_view"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "fleet_vehicles_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_verification_summary"
      referencedColumns: ["vehicle_id"]
    },{
      foreignKeyName: "fleet_vehicles_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicles"
      referencedColumns: ["id"]
    }
                  ]
                },"fleets": {
                  Row: {
                    "billing_address_id": string | null,"commission_rate_override": number | null,"contact_email": string | null,"contact_phone": string | null,"country_id": string,"created_at": string,"id": string,"is_active": boolean,"name": string,"owner_profile_id": string | null,"primary_city_id": string | null,"registration_number": string | null,"tax_id": string | null,"trading_name": string | null,"updated_at": string,"verified_at": string | null,"verified_by": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "billing_address_id"?: string | null,"commission_rate_override"?: number | null,"contact_email"?: string | null,"contact_phone"?: string | null,"country_id": string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"name": string,"owner_profile_id"?: string | null,"primary_city_id"?: string | null,"registration_number"?: string | null,"tax_id"?: string | null,"trading_name"?: string | null,"updated_at"?: string,"verified_at"?: string | null,"verified_by"?: string | null
                  }
                  Update: {
                    "billing_address_id"?: string | null,"commission_rate_override"?: number | null,"contact_email"?: string | null,"contact_phone"?: string | null,"country_id"?: string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"name"?: string,"owner_profile_id"?: string | null,"primary_city_id"?: string | null,"registration_number"?: string | null,"tax_id"?: string | null,"trading_name"?: string | null,"updated_at"?: string,"verified_at"?: string | null,"verified_by"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "fleets_billing_address_id_fkey"
      columns: ["billing_address_id"]
isOneToOne: false
      referencedRelation: "addresses"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "fleets_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "fleets_owner_profile_id_fkey"
      columns: ["owner_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "fleets_primary_city_id_fkey"
      columns: ["primary_city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "fleets_verified_by_fkey"
      columns: ["verified_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"incident_actions": {
                  Row: {
                    "action_type": string,"actor_id": string,"created_at": string,"from_status": string | null,"id": number,"incident_id": string,"metadata": NonNullable<Json>,"notes": string | null,"to_status": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "action_type": string,"actor_id": string,"created_at"?: string,"from_status"?: string | null,"id"?: never,"incident_id": string,"metadata"?: NonNullable<Json>,"notes"?: string | null,"to_status"?: string | null
                  }
                  Update: {
                    "action_type"?: string,"actor_id"?: string,"created_at"?: string,"from_status"?: string | null,"id"?: never,"incident_id"?: string,"metadata"?: NonNullable<Json>,"notes"?: string | null,"to_status"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "incident_actions_actor_id_fkey"
      columns: ["actor_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incident_actions_incident_id_fkey"
      columns: ["incident_id"]
isOneToOne: false
      referencedRelation: "incident_summary"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incident_actions_incident_id_fkey"
      columns: ["incident_id"]
isOneToOne: false
      referencedRelation: "incidents"
      referencedColumns: ["id"]
    }
                  ]
                },"incidents": {
                  Row: {
                    "assigned_to": string | null,"created_at": string,"description": string,"id": string,"incident_type": string,"job_id": string | null,"location": unknown,"occurred_at": string,"reported_by": string,"resolution_summary": string | null,"resolved_at": string | null,"severity": string,"status": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "assigned_to"?: string | null,"created_at"?: string,"description": string,"id"?: string,"incident_type": string,"job_id"?: string | null,"location"?: unknown,"occurred_at": string,"reported_by": string,"resolution_summary"?: string | null,"resolved_at"?: string | null,"severity": string,"status"?: string,"updated_at"?: string
                  }
                  Update: {
                    "assigned_to"?: string | null,"created_at"?: string,"description"?: string,"id"?: string,"incident_type"?: string,"job_id"?: string | null,"location"?: unknown,"occurred_at"?: string,"reported_by"?: string,"resolution_summary"?: string | null,"resolved_at"?: string | null,"severity"?: string,"status"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "incidents_assigned_to_fkey"
      columns: ["assigned_to"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidents_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "incidents_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "incidents_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "incidents_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "incidents_reported_by_fkey"
      columns: ["reported_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"invoice_line_items": {
                  Row: {
                    "amount": number,"created_at": string,"description": string,"id": string,"invoice_id": string,"job_id": string | null,"quantity": number,"unit_price": number
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"created_at"?: string,"description": string,"id"?: string,"invoice_id": string,"job_id"?: string | null,"quantity"?: number,"unit_price": number
                  }
                  Update: {
                    "amount"?: number,"created_at"?: string,"description"?: string,"id"?: string,"invoice_id"?: string,"job_id"?: string | null,"quantity"?: number,"unit_price"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "invoice_line_items_invoice_id_fkey"
      columns: ["invoice_id"]
isOneToOne: false
      referencedRelation: "invoice_summary"
      referencedColumns: ["invoice_id"]
    },{
      foreignKeyName: "invoice_line_items_invoice_id_fkey"
      columns: ["invoice_id"]
isOneToOne: false
      referencedRelation: "invoices"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "invoice_line_items_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "invoice_line_items_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "invoice_line_items_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "invoice_line_items_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"invoices": {
                  Row: {
                    "amount_paid": number,"business_account_id": string,"created_at": string,"currency_code": string,"due_at": string | null,"id": string,"invoice_number": string,"issued_at": string | null,"notes": string | null,"paid_at": string | null,"period_end": string,"period_start": string,"status": string,"subtotal": number,"tax_amount": number,"total": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount_paid"?: number,"business_account_id": string,"created_at"?: string,"currency_code": string,"due_at"?: string | null,"id"?: string,"invoice_number": string,"issued_at"?: string | null,"notes"?: string | null,"paid_at"?: string | null,"period_end": string,"period_start": string,"status"?: string,"subtotal"?: number,"tax_amount"?: number,"total"?: number,"updated_at"?: string
                  }
                  Update: {
                    "amount_paid"?: number,"business_account_id"?: string,"created_at"?: string,"currency_code"?: string,"due_at"?: string | null,"id"?: string,"invoice_number"?: string,"issued_at"?: string | null,"notes"?: string | null,"paid_at"?: string | null,"period_end"?: string,"period_start"?: string,"status"?: string,"subtotal"?: number,"tax_amount"?: number,"total"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "invoices_business_account_id_fkey"
      columns: ["business_account_id"]
isOneToOne: false
      referencedRelation: "business_accounts"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "invoices_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    }
                  ]
                },"job_cancellations": {
                  Row: {
                    "cancellation_policy_id": string | null,"cancelled_by": string,"canceller_role": Database["public"]['Enums']["user_role"],"created_at": string,"currency_code": string | null,"fee_applied": number,"id": string,"job_id": string,"notes": string | null,"reason": string,"refund_amount": number,"refund_status": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "cancellation_policy_id"?: string | null,"cancelled_by": string,"canceller_role": Database["public"]['Enums']["user_role"],"created_at"?: string,"currency_code"?: string | null,"fee_applied"?: number,"id"?: string,"job_id": string,"notes"?: string | null,"reason": string,"refund_amount"?: number,"refund_status"?: string | null
                  }
                  Update: {
                    "cancellation_policy_id"?: string | null,"cancelled_by"?: string,"canceller_role"?: Database["public"]['Enums']["user_role"],"created_at"?: string,"currency_code"?: string | null,"fee_applied"?: number,"id"?: string,"job_id"?: string,"notes"?: string | null,"reason"?: string,"refund_amount"?: number,"refund_status"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "job_cancellations_cancellation_policy_id_fkey"
      columns: ["cancellation_policy_id"]
isOneToOne: false
      referencedRelation: "cancellation_policies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "job_cancellations_cancelled_by_fkey"
      columns: ["cancelled_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "job_cancellations_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "job_cancellations_job_id_fkey"
      columns: ["job_id"]
isOneToOne: true
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_cancellations_job_id_fkey"
      columns: ["job_id"]
isOneToOne: true
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_cancellations_job_id_fkey"
      columns: ["job_id"]
isOneToOne: true
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_cancellations_job_id_fkey"
      columns: ["job_id"]
isOneToOne: true
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"job_events": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    {
      foreignKeyName: "job_events_actor_id_fkey"
      columns: ["actor_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "job_events_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_events_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_events_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_events_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"job_events_2026_10": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_events_2026_11": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_events_2026_12": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_events_2027_01": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_events_2027_02": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_events_2027_03": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_events_2027_04": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_events_2027_05": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_events_2027_06": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_events_2027_07": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_events_2027_08": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_events_2027_09": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_events_default": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"details": NonNullable<Json>,"event_type": string,"id": number,"job_id": string,"location": unknown
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type": string,"id"?: never,"job_id": string,"location"?: unknown
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"details"?: NonNullable<Json>,"event_type"?: string,"id"?: never,"job_id"?: string,"location"?: unknown
                  }
                  Relationships: [
                    
                  ]
                },"job_evidence": {
                  Row: {
                    "created_at": string,"created_by": string | null,"evidence_type": Database["public"]['Enums']["evidence_type"],"file_mime_type": string | null,"file_size_bytes": number | null,"id": string,"job_id": string,"metadata": NonNullable<Json>,"stop_id": string | null,"storage_path": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"created_by"?: string | null,"evidence_type": Database["public"]['Enums']["evidence_type"],"file_mime_type"?: string | null,"file_size_bytes"?: number | null,"id"?: string,"job_id": string,"metadata"?: NonNullable<Json>,"stop_id"?: string | null,"storage_path": string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string | null,"evidence_type"?: Database["public"]['Enums']["evidence_type"],"file_mime_type"?: string | null,"file_size_bytes"?: number | null,"id"?: string,"job_id"?: string,"metadata"?: NonNullable<Json>,"stop_id"?: string | null,"storage_path"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "job_evidence_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "job_evidence_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_evidence_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_evidence_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_evidence_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "job_evidence_stop_id_fkey"
      columns: ["stop_id"]
isOneToOne: false
      referencedRelation: "job_stops"
      referencedColumns: ["id"]
    }
                  ]
                },"job_items": {
                  Row: {
                    "created_at": string,"currency_code": string | null,"declared_value": number | null,"description": string,"id": string,"is_fragile": boolean,"job_id": string,"photo_urls": (string)[],"quantity": number,"requires_special_handling": boolean,"updated_at": string,"volume_m3": number | null,"weight_kg": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"currency_code"?: string | null,"declared_value"?: number | null,"description": string,"id"?: string,"is_fragile"?: boolean,"job_id": string,"photo_urls"?: (string)[],"quantity"?: number,"requires_special_handling"?: boolean,"updated_at"?: string,"volume_m3"?: number | null,"weight_kg"?: number | null
                  }
                  Update: {
                    "created_at"?: string,"currency_code"?: string | null,"declared_value"?: number | null,"description"?: string,"id"?: string,"is_fragile"?: boolean,"job_id"?: string,"photo_urls"?: (string)[],"quantity"?: number,"requires_special_handling"?: boolean,"updated_at"?: string,"volume_m3"?: number | null,"weight_kg"?: number | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "job_items_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "job_items_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_items_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_items_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_items_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"job_offers": {
                  Row: {
                    "created_at": string,"currency_code": string | null,"decline_reason": string | null,"distance_to_pickup_km": number | null,"driver_id": string,"eta_minutes": number | null,"expires_at": string,"id": string,"job_id": string,"offer_sequence": number,"offered_at": string,"payout_estimate": number | null,"responded_at": string | null,"response": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"currency_code"?: string | null,"decline_reason"?: string | null,"distance_to_pickup_km"?: number | null,"driver_id": string,"eta_minutes"?: number | null,"expires_at": string,"id"?: string,"job_id": string,"offer_sequence"?: number,"offered_at"?: string,"payout_estimate"?: number | null,"responded_at"?: string | null,"response"?: string
                  }
                  Update: {
                    "created_at"?: string,"currency_code"?: string | null,"decline_reason"?: string | null,"distance_to_pickup_km"?: number | null,"driver_id"?: string,"eta_minutes"?: number | null,"expires_at"?: string,"id"?: string,"job_id"?: string,"offer_sequence"?: number,"offered_at"?: string,"payout_estimate"?: number | null,"responded_at"?: string | null,"response"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "job_offers_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "job_offers_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "job_offers_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "job_offers_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "job_offers_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_offers_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_offers_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_offers_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"job_status_history": {
                  Row: {
                    "changed_by": string | null,"created_at": string,"from_status": Database["public"]['Enums']["job_status"] | null,"id": number,"job_id": string,"location": unknown,"reason": string | null,"to_status": Database["public"]['Enums']["job_status"]
                  }
                  ComputedFields: never
                  Insert: {
                    "changed_by"?: string | null,"created_at"?: string,"from_status"?: Database["public"]['Enums']["job_status"] | null,"id"?: never,"job_id": string,"location"?: unknown,"reason"?: string | null,"to_status": Database["public"]['Enums']["job_status"]
                  }
                  Update: {
                    "changed_by"?: string | null,"created_at"?: string,"from_status"?: Database["public"]['Enums']["job_status"] | null,"id"?: never,"job_id"?: string,"location"?: unknown,"reason"?: string | null,"to_status"?: Database["public"]['Enums']["job_status"]
                  }
                  Relationships: [
                    {
      foreignKeyName: "job_status_history_changed_by_fkey"
      columns: ["changed_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "job_status_history_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_status_history_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_status_history_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_status_history_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"job_stops": {
                  Row: {
                    "address": string,"arrived_at": string | null,"completed_at": string | null,"contact_name": string | null,"contact_phone": string | null,"created_at": string,"id": string,"job_id": string,"location": unknown,"notes": string | null,"stop_sequence": number,"stop_type": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "address": string,"arrived_at"?: string | null,"completed_at"?: string | null,"contact_name"?: string | null,"contact_phone"?: string | null,"created_at"?: string,"id"?: string,"job_id": string,"location": unknown,"notes"?: string | null,"stop_sequence": number,"stop_type": string,"updated_at"?: string
                  }
                  Update: {
                    "address"?: string,"arrived_at"?: string | null,"completed_at"?: string | null,"contact_name"?: string | null,"contact_phone"?: string | null,"created_at"?: string,"id"?: string,"job_id"?: string,"location"?: unknown,"notes"?: string | null,"stop_sequence"?: number,"stop_type"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "job_stops_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_stops_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_stops_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "job_stops_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"jobs": {
                  Row: {
                    "accepted_at": string | null,"actual_distance_km": number | null,"actual_duration_min": number | null,"cancellation_fee": number,"cancellation_policy_applied": string | null,"cancelled_at": string | null,"city_id": string,"completed_at": string | null,"created_at": string,"customer_id": string,"distance_km": number,"driver_id": string | null,"final_amount": number | null,"final_currency_code": string | null,"id": string,"notes": string | null,"payment_method": Database["public"]['Enums']["payment_method"] | null,"payment_status": Database["public"]['Enums']["payment_status"],"quote_id": string,"scheduled_at": string | null,"started_at": string | null,"status": Database["public"]['Enums']["job_status"],"updated_at": string,"vehicle_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "accepted_at"?: string | null,"actual_distance_km"?: number | null,"actual_duration_min"?: number | null,"cancellation_fee"?: number,"cancellation_policy_applied"?: string | null,"cancelled_at"?: string | null,"city_id": string,"completed_at"?: string | null,"created_at"?: string,"customer_id": string,"distance_km": number,"driver_id"?: string | null,"final_amount"?: number | null,"final_currency_code"?: string | null,"id"?: string,"notes"?: string | null,"payment_method"?: Database["public"]['Enums']["payment_method"] | null,"payment_status"?: Database["public"]['Enums']["payment_status"],"quote_id": string,"scheduled_at"?: string | null,"started_at"?: string | null,"status"?: Database["public"]['Enums']["job_status"],"updated_at"?: string,"vehicle_id"?: string | null
                  }
                  Update: {
                    "accepted_at"?: string | null,"actual_distance_km"?: number | null,"actual_duration_min"?: number | null,"cancellation_fee"?: number,"cancellation_policy_applied"?: string | null,"cancelled_at"?: string | null,"city_id"?: string,"completed_at"?: string | null,"created_at"?: string,"customer_id"?: string,"distance_km"?: number,"driver_id"?: string | null,"final_amount"?: number | null,"final_currency_code"?: string | null,"id"?: string,"notes"?: string | null,"payment_method"?: Database["public"]['Enums']["payment_method"] | null,"payment_status"?: Database["public"]['Enums']["payment_status"],"quote_id"?: string,"scheduled_at"?: string | null,"started_at"?: string | null,"status"?: Database["public"]['Enums']["job_status"],"updated_at"?: string,"vehicle_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "jobs_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "jobs_customer_id_fkey"
      columns: ["customer_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "jobs_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "jobs_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "jobs_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "jobs_final_currency_code_fkey"
      columns: ["final_currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "jobs_quote_id_fkey"
      columns: ["quote_id"]
isOneToOne: false
      referencedRelation: "quote_summary"
      referencedColumns: ["quote_id"]
    },{
      foreignKeyName: "jobs_quote_id_fkey"
      columns: ["quote_id"]
isOneToOne: false
      referencedRelation: "quotes"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "jobs_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_public_view"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "jobs_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_verification_summary"
      referencedColumns: ["vehicle_id"]
    },{
      foreignKeyName: "jobs_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicles"
      referencedColumns: ["id"]
    }
                  ]
                },"languages": {
                  Row: {
                    "code": string,"created_at": string,"id": string,"is_active": boolean,"name": string,"native_name": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "code": string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"name": string,"native_name"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "code"?: string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"name"?: string,"native_name"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"localization_strings": {
                  Row: {
                    "context": string | null,"created_at": string,"id": string,"is_active": boolean,"key": string,"language_id": string,"namespace": string,"updated_at": string,"value": string
                  }
                  ComputedFields: never
                  Insert: {
                    "context"?: string | null,"created_at"?: string,"id"?: string,"is_active"?: boolean,"key": string,"language_id": string,"namespace": string,"updated_at"?: string,"value": string
                  }
                  Update: {
                    "context"?: string | null,"created_at"?: string,"id"?: string,"is_active"?: boolean,"key"?: string,"language_id"?: string,"namespace"?: string,"updated_at"?: string,"value"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "localization_strings_language_id_fkey"
      columns: ["language_id"]
isOneToOne: false
      referencedRelation: "languages"
      referencedColumns: ["id"]
    }
                  ]
                },"matching_attempts": {
                  Row: {
                    "attempt_number": number,"created_at": string,"drivers_considered": number,"drivers_offered": number,"ended_at": string | null,"failure_reason": string | null,"id": string,"job_id": string,"match_successful": boolean,"matched_driver_id": string | null,"metadata": NonNullable<Json>,"started_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "attempt_number": number,"created_at"?: string,"drivers_considered"?: number,"drivers_offered"?: number,"ended_at"?: string | null,"failure_reason"?: string | null,"id"?: string,"job_id": string,"match_successful"?: boolean,"matched_driver_id"?: string | null,"metadata"?: NonNullable<Json>,"started_at"?: string
                  }
                  Update: {
                    "attempt_number"?: number,"created_at"?: string,"drivers_considered"?: number,"drivers_offered"?: number,"ended_at"?: string | null,"failure_reason"?: string | null,"id"?: string,"job_id"?: string,"match_successful"?: boolean,"matched_driver_id"?: string | null,"metadata"?: NonNullable<Json>,"started_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "matching_attempts_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "matching_attempts_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "matching_attempts_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "matching_attempts_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "matching_attempts_matched_driver_id_fkey"
      columns: ["matched_driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "matching_attempts_matched_driver_id_fkey"
      columns: ["matched_driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "matching_attempts_matched_driver_id_fkey"
      columns: ["matched_driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    }
                  ]
                },"neighborhoods": {
                  Row: {
                    "boundary": unknown,"centroid": unknown,"city_id": string,"created_at": string,"id": string,"is_active": boolean,"name": string,"service_zone_id": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "boundary"?: unknown,"centroid"?: unknown,"city_id": string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"name": string,"service_zone_id"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "boundary"?: unknown,"centroid"?: unknown,"city_id"?: string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"name"?: string,"service_zone_id"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "neighborhoods_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "neighborhoods_service_zone_id_fkey"
      columns: ["service_zone_id"]
isOneToOne: false
      referencedRelation: "service_zones"
      referencedColumns: ["id"]
    }
                  ]
                },"notification_log": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "notification_log_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"notification_log_2026_10": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2026_11": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2026_12": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2027_01": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2027_02": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2027_03": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2027_04": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2027_05": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2027_06": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2027_07": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2027_08": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2027_09": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2027_10": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2027_11": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2027_12": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2028_01": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2028_02": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2028_03": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2028_04": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2028_05": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2028_06": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2028_07": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2028_08": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_2028_09": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_log_default": {
                  Row: {
                    "body": string,"channel": string,"created_at": string,"delivered_at": string | null,"failure_reason": string | null,"id": number,"profile_id": string,"provider": string | null,"provider_message_id": string | null,"provider_response": Json | null,"public_id": string,"read_at": string | null,"recipient": string,"reference_id": string | null,"reference_type": string | null,"sent_at": string | null,"status": string,"subject": string | null,"template_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"channel": string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id": string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient": string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Update: {
                    "body"?: string,"channel"?: string,"created_at"?: string,"delivered_at"?: string | null,"failure_reason"?: string | null,"id"?: never,"profile_id"?: string,"provider"?: string | null,"provider_message_id"?: string | null,"provider_response"?: Json | null,"public_id"?: string,"read_at"?: string | null,"recipient"?: string,"reference_id"?: string | null,"reference_type"?: string | null,"sent_at"?: string | null,"status"?: string,"subject"?: string | null,"template_code"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"notification_preferences": {
                  Row: {
                    "category": string,"channel": string,"id": string,"is_enabled": boolean,"profile_id": string,"quiet_hours_end": string | null,"quiet_hours_start": string | null,"timezone": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "category": string,"channel": string,"id"?: string,"is_enabled"?: boolean,"profile_id": string,"quiet_hours_end"?: string | null,"quiet_hours_start"?: string | null,"timezone"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "category"?: string,"channel"?: string,"id"?: string,"is_enabled"?: boolean,"profile_id"?: string,"quiet_hours_end"?: string | null,"quiet_hours_start"?: string | null,"timezone"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "notification_preferences_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"notification_templates": {
                  Row: {
                    "body_template": string,"channel": string,"code": string,"country_id": string | null,"created_at": string,"deep_link_template": string | null,"id": string,"is_active": boolean,"language_id": string,"title_template": string | null,"updated_at": string,"variables": (string)[]
                  }
                  ComputedFields: never
                  Insert: {
                    "body_template": string,"channel": string,"code": string,"country_id"?: string | null,"created_at"?: string,"deep_link_template"?: string | null,"id"?: string,"is_active"?: boolean,"language_id": string,"title_template"?: string | null,"updated_at"?: string,"variables"?: (string)[]
                  }
                  Update: {
                    "body_template"?: string,"channel"?: string,"code"?: string,"country_id"?: string | null,"created_at"?: string,"deep_link_template"?: string | null,"id"?: string,"is_active"?: boolean,"language_id"?: string,"title_template"?: string | null,"updated_at"?: string,"variables"?: (string)[]
                  }
                  Relationships: [
                    {
      foreignKeyName: "notification_templates_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "notification_templates_language_id_fkey"
      columns: ["language_id"]
isOneToOne: false
      referencedRelation: "languages"
      referencedColumns: ["id"]
    }
                  ]
                },"payment_methods": {
                  Row: {
                    "created_at": string,"display_name": string | null,"expires_at": string | null,"id": string,"is_active": boolean,"is_default": boolean,"last_used_at": string | null,"metadata": NonNullable<Json>,"method_type": Database["public"]['Enums']["payment_method"],"profile_id": string,"provider_customer_id": string | null,"provider_id": string,"provider_token": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"display_name"?: string | null,"expires_at"?: string | null,"id"?: string,"is_active"?: boolean,"is_default"?: boolean,"last_used_at"?: string | null,"metadata"?: NonNullable<Json>,"method_type": Database["public"]['Enums']["payment_method"],"profile_id": string,"provider_customer_id"?: string | null,"provider_id": string,"provider_token": string,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"display_name"?: string | null,"expires_at"?: string | null,"id"?: string,"is_active"?: boolean,"is_default"?: boolean,"last_used_at"?: string | null,"metadata"?: NonNullable<Json>,"method_type"?: Database["public"]['Enums']["payment_method"],"profile_id"?: string,"provider_customer_id"?: string | null,"provider_id"?: string,"provider_token"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "payment_methods_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "payment_methods_provider_id_fkey"
      columns: ["provider_id"]
isOneToOne: false
      referencedRelation: "payment_providers"
      referencedColumns: ["id"]
    }
                  ]
                },"payment_providers": {
                  Row: {
                    "code": string,"config": NonNullable<Json>,"country_id": string,"created_at": string,"id": string,"is_active": boolean,"name": string,"provider_type": string,"supports_partial_refunds": boolean,"supports_payouts": boolean,"supports_refunds": boolean,"updated_at": string,"webhook_secret_reference": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "code": string,"config"?: NonNullable<Json>,"country_id": string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"name": string,"provider_type": string,"supports_partial_refunds"?: boolean,"supports_payouts"?: boolean,"supports_refunds"?: boolean,"updated_at"?: string,"webhook_secret_reference"?: string | null
                  }
                  Update: {
                    "code"?: string,"config"?: NonNullable<Json>,"country_id"?: string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"name"?: string,"provider_type"?: string,"supports_partial_refunds"?: boolean,"supports_payouts"?: boolean,"supports_refunds"?: boolean,"updated_at"?: string,"webhook_secret_reference"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "payment_providers_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    }
                  ]
                },"payment_webhooks": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    {
      foreignKeyName: "payment_webhooks_provider_id_fkey"
      columns: ["provider_id"]
isOneToOne: false
      referencedRelation: "payment_providers"
      referencedColumns: ["id"]
    }
                  ]
                },"payment_webhooks_2026_10": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2026_11": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2026_12": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2027_01": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2027_02": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2027_03": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2027_04": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2027_05": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2027_06": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2027_07": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2027_08": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2027_09": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2027_10": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2027_11": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2027_12": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2028_01": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2028_02": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2028_03": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2028_04": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2028_05": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2028_06": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2028_07": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2028_08": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_2028_09": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payment_webhooks_default": {
                  Row: {
                    "created_at": string,"event_id": string | null,"event_type": string,"id": number,"payload": NonNullable<Json>,"processed_at": string | null,"processing_error": string | null,"processing_status": string,"provider_id": string,"provider_reference": string | null,"received_at": string,"signature_header": string | null,"signature_valid": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"event_id"?: string | null,"event_type": string,"id"?: never,"payload": NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id": string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Update: {
                    "created_at"?: string,"event_id"?: string | null,"event_type"?: string,"id"?: never,"payload"?: NonNullable<Json>,"processed_at"?: string | null,"processing_error"?: string | null,"processing_status"?: string,"provider_id"?: string,"provider_reference"?: string | null,"received_at"?: string,"signature_header"?: string | null,"signature_valid"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"payments": {
                  Row: {
                    "amount": number,"completed_at": string | null,"created_at": string,"currency_code": string,"customer_id": string,"failure_code": string | null,"failure_reason": string | null,"id": string,"initiated_at": string,"job_id": string,"metadata": NonNullable<Json>,"payment_method_id": string | null,"payment_type": string,"provider_id": string,"provider_reference": string | null,"provider_status": string,"refund_of_payment_id": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"completed_at"?: string | null,"created_at"?: string,"currency_code": string,"customer_id": string,"failure_code"?: string | null,"failure_reason"?: string | null,"id"?: string,"initiated_at"?: string,"job_id": string,"metadata"?: NonNullable<Json>,"payment_method_id"?: string | null,"payment_type"?: string,"provider_id": string,"provider_reference"?: string | null,"provider_status"?: string,"refund_of_payment_id"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "amount"?: number,"completed_at"?: string | null,"created_at"?: string,"currency_code"?: string,"customer_id"?: string,"failure_code"?: string | null,"failure_reason"?: string | null,"id"?: string,"initiated_at"?: string,"job_id"?: string,"metadata"?: NonNullable<Json>,"payment_method_id"?: string | null,"payment_type"?: string,"provider_id"?: string,"provider_reference"?: string | null,"provider_status"?: string,"refund_of_payment_id"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "payments_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "payments_customer_id_fkey"
      columns: ["customer_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "payments_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "payments_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "payments_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "payments_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "payments_payment_method_id_fkey"
      columns: ["payment_method_id"]
isOneToOne: false
      referencedRelation: "payment_methods"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "payments_provider_id_fkey"
      columns: ["provider_id"]
isOneToOne: false
      referencedRelation: "payment_providers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "payments_refund_of_payment_id_fkey"
      columns: ["refund_of_payment_id"]
isOneToOne: false
      referencedRelation: "payment_reconciliation"
      referencedColumns: ["payment_id"]
    },{
      foreignKeyName: "payments_refund_of_payment_id_fkey"
      columns: ["refund_of_payment_id"]
isOneToOne: false
      referencedRelation: "payments"
      referencedColumns: ["id"]
    }
                  ]
                },"payout_batches": {
                  Row: {
                    "completed_at": string | null,"country_id": string,"created_at": string,"currency_code": string,"driver_count": number,"failure_reason": string | null,"id": string,"initiated_by": string | null,"period_end": string,"period_start": string,"status": string,"total_amount": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "completed_at"?: string | null,"country_id": string,"created_at"?: string,"currency_code": string,"driver_count"?: number,"failure_reason"?: string | null,"id"?: string,"initiated_by"?: string | null,"period_end": string,"period_start": string,"status"?: string,"total_amount"?: number,"updated_at"?: string
                  }
                  Update: {
                    "completed_at"?: string | null,"country_id"?: string,"created_at"?: string,"currency_code"?: string,"driver_count"?: number,"failure_reason"?: string | null,"id"?: string,"initiated_by"?: string | null,"period_end"?: string,"period_start"?: string,"status"?: string,"total_amount"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "payout_batches_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "payout_batches_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "payout_batches_initiated_by_fkey"
      columns: ["initiated_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"payout_items": {
                  Row: {
                    "amount": number,"commission_calculated_at": string,"commission_ledger_id": string,"created_at": string,"id": string,"job_id": string,"payout_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"commission_calculated_at": string,"commission_ledger_id": string,"created_at"?: string,"id"?: string,"job_id": string,"payout_id": string
                  }
                  Update: {
                    "amount"?: number,"commission_calculated_at"?: string,"commission_ledger_id"?: string,"created_at"?: string,"id"?: string,"job_id"?: string,"payout_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "payout_items_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "payout_items_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "payout_items_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "payout_items_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "payout_items_ledger_fkey"
      columns: ["commission_ledger_id","commission_calculated_at"]
isOneToOne: false
      referencedRelation: "commission_ledger"
      referencedColumns: ["id","calculated_at"]
    },{
      foreignKeyName: "payout_items_payout_id_fkey"
      columns: ["payout_id"]
isOneToOne: false
      referencedRelation: "payouts"
      referencedColumns: ["id"]
    }
                  ]
                },"payouts": {
                  Row: {
                    "amount": number,"batch_id": string | null,"commission_deducted": number,"completed_at": string | null,"created_at": string,"currency_code": string,"driver_id": string,"failure_reason": string | null,"gross_earnings": number,"id": string,"initiated_at": string,"net_amount": number,"payment_method_id": string | null,"payment_provider_id": string | null,"period_end": string,"period_start": string,"provider_reference": string | null,"status": string,"updated_at": string,"withholding_tax": number
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"batch_id"?: string | null,"commission_deducted"?: number,"completed_at"?: string | null,"created_at"?: string,"currency_code": string,"driver_id": string,"failure_reason"?: string | null,"gross_earnings": number,"id"?: string,"initiated_at"?: string,"net_amount": number,"payment_method_id"?: string | null,"payment_provider_id"?: string | null,"period_end": string,"period_start": string,"provider_reference"?: string | null,"status"?: string,"updated_at"?: string,"withholding_tax"?: number
                  }
                  Update: {
                    "amount"?: number,"batch_id"?: string | null,"commission_deducted"?: number,"completed_at"?: string | null,"created_at"?: string,"currency_code"?: string,"driver_id"?: string,"failure_reason"?: string | null,"gross_earnings"?: number,"id"?: string,"initiated_at"?: string,"net_amount"?: number,"payment_method_id"?: string | null,"payment_provider_id"?: string | null,"period_end"?: string,"period_start"?: string,"provider_reference"?: string | null,"status"?: string,"updated_at"?: string,"withholding_tax"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "payouts_batch_id_fkey"
      columns: ["batch_id"]
isOneToOne: false
      referencedRelation: "payout_batch_summary"
      referencedColumns: ["batch_id"]
    },{
      foreignKeyName: "payouts_batch_id_fkey"
      columns: ["batch_id"]
isOneToOne: false
      referencedRelation: "payout_batches"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "payouts_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "payouts_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "payouts_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "payouts_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "payouts_payment_method_id_fkey"
      columns: ["payment_method_id"]
isOneToOne: false
      referencedRelation: "payment_methods"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "payouts_payment_provider_id_fkey"
      columns: ["payment_provider_id"]
isOneToOne: false
      referencedRelation: "payment_providers"
      referencedColumns: ["id"]
    }
                  ]
                },"pricing_cargo_surcharges": {
                  Row: {
                    "cargo_type_id": string,"created_at": string,"currency_code": string,"id": string,"pricing_plan_version_id": string,"surcharge_type": string,"surcharge_value": number
                  }
                  ComputedFields: never
                  Insert: {
                    "cargo_type_id": string,"created_at"?: string,"currency_code": string,"id"?: string,"pricing_plan_version_id": string,"surcharge_type": string,"surcharge_value": number
                  }
                  Update: {
                    "cargo_type_id"?: string,"created_at"?: string,"currency_code"?: string,"id"?: string,"pricing_plan_version_id"?: string,"surcharge_type"?: string,"surcharge_value"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "pricing_cargo_surcharges_cargo_type_id_fkey"
      columns: ["cargo_type_id"]
isOneToOne: false
      referencedRelation: "cargo_types"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "pricing_cargo_surcharges_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "pricing_cargo_surcharges_pricing_plan_version_id_fkey"
      columns: ["pricing_plan_version_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    }
                  ]
                },"pricing_distance_tiers": {
                  Row: {
                    "created_at": string,"currency_code": string,"display_order": number,"id": string,"max_km": number | null,"min_km": number,"per_km_rate": number,"pricing_plan_version_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"currency_code": string,"display_order"?: number,"id"?: string,"max_km"?: number | null,"min_km": number,"per_km_rate": number,"pricing_plan_version_id": string
                  }
                  Update: {
                    "created_at"?: string,"currency_code"?: string,"display_order"?: number,"id"?: string,"max_km"?: number | null,"min_km"?: number,"per_km_rate"?: number,"pricing_plan_version_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "pricing_distance_tiers_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "pricing_distance_tiers_pricing_plan_version_id_fkey"
      columns: ["pricing_plan_version_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    }
                  ]
                },"pricing_equipment_surcharges": {
                  Row: {
                    "created_at": string,"currency_code": string,"equipment_id": string,"id": string,"pricing_plan_version_id": string,"surcharge_type": string,"surcharge_value": number
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"currency_code": string,"equipment_id": string,"id"?: string,"pricing_plan_version_id": string,"surcharge_type": string,"surcharge_value": number
                  }
                  Update: {
                    "created_at"?: string,"currency_code"?: string,"equipment_id"?: string,"id"?: string,"pricing_plan_version_id"?: string,"surcharge_type"?: string,"surcharge_value"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "pricing_equipment_surcharges_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "pricing_equipment_surcharges_equipment_id_fkey"
      columns: ["equipment_id"]
isOneToOne: false
      referencedRelation: "vehicle_equipment_catalog"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "pricing_equipment_surcharges_pricing_plan_version_id_fkey"
      columns: ["pricing_plan_version_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    }
                  ]
                },"pricing_plan_base_rates": {
                  Row: {
                    "base_fare": number,"created_at": string,"currency_code": string,"id": string,"loading_fee": number,"minimum_charge": number,"multi_stop_fee": number,"per_km_rate": number,"per_min_rate": number,"pricing_plan_version_id": string,"unloading_fee": number,"vat_rate": number,"waiting_free_minutes": number,"waiting_per_min_rate": number
                  }
                  ComputedFields: never
                  Insert: {
                    "base_fare": number,"created_at"?: string,"currency_code": string,"id"?: string,"loading_fee"?: number,"minimum_charge"?: number,"multi_stop_fee"?: number,"per_km_rate": number,"per_min_rate": number,"pricing_plan_version_id": string,"unloading_fee"?: number,"vat_rate"?: number,"waiting_free_minutes"?: number,"waiting_per_min_rate"?: number
                  }
                  Update: {
                    "base_fare"?: number,"created_at"?: string,"currency_code"?: string,"id"?: string,"loading_fee"?: number,"minimum_charge"?: number,"multi_stop_fee"?: number,"per_km_rate"?: number,"per_min_rate"?: number,"pricing_plan_version_id"?: string,"unloading_fee"?: number,"vat_rate"?: number,"waiting_free_minutes"?: number,"waiting_per_min_rate"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "pricing_plan_base_rates_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "pricing_plan_base_rates_pricing_plan_version_id_fkey"
      columns: ["pricing_plan_version_id"]
isOneToOne: true
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    }
                  ]
                },"pricing_plan_vehicle_types": {
                  Row: {
                    "created_at": string,"id": string,"pricing_plan_version_id": string,"vehicle_type_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"pricing_plan_version_id": string,"vehicle_type_id": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"pricing_plan_version_id"?: string,"vehicle_type_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "pricing_plan_vehicle_types_pricing_plan_version_id_fkey"
      columns: ["pricing_plan_version_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "pricing_plan_vehicle_types_vehicle_type_id_fkey"
      columns: ["vehicle_type_id"]
isOneToOne: false
      referencedRelation: "vehicle_types"
      referencedColumns: ["id"]
    }
                  ]
                },"pricing_plan_versions": {
                  Row: {
                    "created_at": string,"currency_code": string,"effective_from": string,"effective_to": string | null,"id": string,"notes": string | null,"pricing_plan_id": string,"published_at": string | null,"published_by": string | null,"regulated_tariff_id": string | null,"superseded_by_version_id": string | null,"updated_at": string,"version_number": number
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"currency_code": string,"effective_from": string,"effective_to"?: string | null,"id"?: string,"notes"?: string | null,"pricing_plan_id": string,"published_at"?: string | null,"published_by"?: string | null,"regulated_tariff_id"?: string | null,"superseded_by_version_id"?: string | null,"updated_at"?: string,"version_number": number
                  }
                  Update: {
                    "created_at"?: string,"currency_code"?: string,"effective_from"?: string,"effective_to"?: string | null,"id"?: string,"notes"?: string | null,"pricing_plan_id"?: string,"published_at"?: string | null,"published_by"?: string | null,"regulated_tariff_id"?: string | null,"superseded_by_version_id"?: string | null,"updated_at"?: string,"version_number"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "pricing_plan_versions_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "pricing_plan_versions_pricing_plan_id_fkey"
      columns: ["pricing_plan_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_summary"
      referencedColumns: ["plan_id"]
    },{
      foreignKeyName: "pricing_plan_versions_pricing_plan_id_fkey"
      columns: ["pricing_plan_id"]
isOneToOne: false
      referencedRelation: "pricing_plans"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "pricing_plan_versions_published_by_fkey"
      columns: ["published_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "pricing_plan_versions_regulated_tariff_id_fkey"
      columns: ["regulated_tariff_id"]
isOneToOne: false
      referencedRelation: "regulated_tariff_bands_summary"
      referencedColumns: ["tariff_id"]
    },{
      foreignKeyName: "pricing_plan_versions_regulated_tariff_id_fkey"
      columns: ["regulated_tariff_id"]
isOneToOne: false
      referencedRelation: "regulated_tariffs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "pricing_plan_versions_superseded_by_version_id_fkey"
      columns: ["superseded_by_version_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    }
                  ]
                },"pricing_plan_zones": {
                  Row: {
                    "created_at": string,"id": string,"is_primary": boolean,"pricing_plan_version_id": string,"service_zone_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"is_primary"?: boolean,"pricing_plan_version_id": string,"service_zone_id": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"is_primary"?: boolean,"pricing_plan_version_id"?: string,"service_zone_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "pricing_plan_zones_pricing_plan_version_id_fkey"
      columns: ["pricing_plan_version_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "pricing_plan_zones_service_zone_id_fkey"
      columns: ["service_zone_id"]
isOneToOne: false
      referencedRelation: "service_zones"
      referencedColumns: ["id"]
    }
                  ]
                },"pricing_plans": {
                  Row: {
                    "city_id": string,"code": string,"country_id": string,"created_at": string,"description": string | null,"display_order": number,"id": string,"is_active": boolean,"name": string,"service_zone_id": string | null,"updated_at": string,"vehicle_type_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "city_id": string,"code": string,"country_id": string,"created_at"?: string,"description"?: string | null,"display_order"?: number,"id"?: string,"is_active"?: boolean,"name": string,"service_zone_id"?: string | null,"updated_at"?: string,"vehicle_type_id": string
                  }
                  Update: {
                    "city_id"?: string,"code"?: string,"country_id"?: string,"created_at"?: string,"description"?: string | null,"display_order"?: number,"id"?: string,"is_active"?: boolean,"name"?: string,"service_zone_id"?: string | null,"updated_at"?: string,"vehicle_type_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "pricing_plans_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "pricing_plans_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "pricing_plans_service_zone_id_fkey"
      columns: ["service_zone_id"]
isOneToOne: false
      referencedRelation: "service_zones"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "pricing_plans_vehicle_type_id_fkey"
      columns: ["vehicle_type_id"]
isOneToOne: false
      referencedRelation: "vehicle_types"
      referencedColumns: ["id"]
    }
                  ]
                },"pricing_time_multipliers": {
                  Row: {
                    "applies_to": string,"created_at": string,"days_of_week": (number)[],"end_time": string,"id": string,"multiplier": number,"name": string,"pricing_plan_version_id": string,"priority": number,"stacks": boolean,"start_time": string,"timezone": string
                  }
                  ComputedFields: never
                  Insert: {
                    "applies_to"?: string,"created_at"?: string,"days_of_week": (number)[],"end_time": string,"id"?: string,"multiplier": number,"name": string,"pricing_plan_version_id": string,"priority"?: number,"stacks"?: boolean,"start_time": string,"timezone"?: string
                  }
                  Update: {
                    "applies_to"?: string,"created_at"?: string,"days_of_week"?: (number)[],"end_time"?: string,"id"?: string,"multiplier"?: number,"name"?: string,"pricing_plan_version_id"?: string,"priority"?: number,"stacks"?: boolean,"start_time"?: string,"timezone"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "pricing_time_multipliers_pricing_plan_version_id_fkey"
      columns: ["pricing_plan_version_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    }
                  ]
                },"pricing_volume_tiers": {
                  Row: {
                    "created_at": string,"currency_code": string,"display_order": number,"id": string,"max_m3": number | null,"min_m3": number,"pricing_plan_version_id": string,"surcharge_type": string,"surcharge_value": number
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"currency_code": string,"display_order"?: number,"id"?: string,"max_m3"?: number | null,"min_m3": number,"pricing_plan_version_id": string,"surcharge_type": string,"surcharge_value": number
                  }
                  Update: {
                    "created_at"?: string,"currency_code"?: string,"display_order"?: number,"id"?: string,"max_m3"?: number | null,"min_m3"?: number,"pricing_plan_version_id"?: string,"surcharge_type"?: string,"surcharge_value"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "pricing_volume_tiers_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "pricing_volume_tiers_pricing_plan_version_id_fkey"
      columns: ["pricing_plan_version_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    }
                  ]
                },"pricing_weight_tiers": {
                  Row: {
                    "created_at": string,"currency_code": string,"display_order": number,"id": string,"max_kg": number | null,"min_kg": number,"pricing_plan_version_id": string,"surcharge_type": string,"surcharge_value": number
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"currency_code": string,"display_order"?: number,"id"?: string,"max_kg"?: number | null,"min_kg": number,"pricing_plan_version_id": string,"surcharge_type": string,"surcharge_value": number
                  }
                  Update: {
                    "created_at"?: string,"currency_code"?: string,"display_order"?: number,"id"?: string,"max_kg"?: number | null,"min_kg"?: number,"pricing_plan_version_id"?: string,"surcharge_type"?: string,"surcharge_value"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "pricing_weight_tiers_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "pricing_weight_tiers_pricing_plan_version_id_fkey"
      columns: ["pricing_plan_version_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    }
                  ]
                },"pricing_zone_multipliers": {
                  Row: {
                    "created_at": string,"id": string,"multiplier": number,"pricing_plan_version_id": string,"reason": string | null,"service_zone_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"multiplier": number,"pricing_plan_version_id": string,"reason"?: string | null,"service_zone_id": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"multiplier"?: number,"pricing_plan_version_id"?: string,"reason"?: string | null,"service_zone_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "pricing_zone_multipliers_pricing_plan_version_id_fkey"
      columns: ["pricing_plan_version_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "pricing_zone_multipliers_service_zone_id_fkey"
      columns: ["service_zone_id"]
isOneToOne: false
      referencedRelation: "service_zones"
      referencedColumns: ["id"]
    }
                  ]
                },"profiles": {
                  Row: {
                    "avatar_url": string | null,"created_at": string,"deactivated_at": string | null,"deactivation_reason": string | null,"default_country_id": string | null,"display_name": string | null,"email": string | null,"email_verified": boolean,"full_name": string | null,"id": string,"is_active": boolean,"last_login_at": string | null,"last_login_ip": unknown,"marketing_opt_in": boolean,"phone": string | null,"phone_verified": boolean,"preferred_currency_id": string | null,"preferred_language_id": string | null,"primary_role": Database["public"]['Enums']["user_role"],"privacy_accepted_at": string | null,"terms_accepted_at": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "avatar_url"?: string | null,"created_at"?: string,"deactivated_at"?: string | null,"deactivation_reason"?: string | null,"default_country_id"?: string | null,"display_name"?: string | null,"email"?: string | null,"email_verified"?: boolean,"full_name"?: string | null,"id": string,"is_active"?: boolean,"last_login_at"?: string | null,"last_login_ip"?: unknown,"marketing_opt_in"?: boolean,"phone"?: string | null,"phone_verified"?: boolean,"preferred_currency_id"?: string | null,"preferred_language_id"?: string | null,"primary_role"?: Database["public"]['Enums']["user_role"],"privacy_accepted_at"?: string | null,"terms_accepted_at"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "avatar_url"?: string | null,"created_at"?: string,"deactivated_at"?: string | null,"deactivation_reason"?: string | null,"default_country_id"?: string | null,"display_name"?: string | null,"email"?: string | null,"email_verified"?: boolean,"full_name"?: string | null,"id"?: string,"is_active"?: boolean,"last_login_at"?: string | null,"last_login_ip"?: unknown,"marketing_opt_in"?: boolean,"phone"?: string | null,"phone_verified"?: boolean,"preferred_currency_id"?: string | null,"preferred_language_id"?: string | null,"primary_role"?: Database["public"]['Enums']["user_role"],"privacy_accepted_at"?: string | null,"terms_accepted_at"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "profiles_default_country_id_fkey"
      columns: ["default_country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "profiles_preferred_currency_id_fkey"
      columns: ["preferred_currency_id"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "profiles_preferred_language_id_fkey"
      columns: ["preferred_language_id"]
isOneToOne: false
      referencedRelation: "languages"
      referencedColumns: ["id"]
    }
                  ]
                },"prohibited_items": {
                  Row: {
                    "category": string,"country_id": string,"created_at": string,"description": string | null,"id": string,"is_active": boolean,"legal_reference": string | null,"name": string,"severity": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "category": string,"country_id": string,"created_at"?: string,"description"?: string | null,"id"?: string,"is_active"?: boolean,"legal_reference"?: string | null,"name": string,"severity": string,"updated_at"?: string
                  }
                  Update: {
                    "category"?: string,"country_id"?: string,"created_at"?: string,"description"?: string | null,"id"?: string,"is_active"?: boolean,"legal_reference"?: string | null,"name"?: string,"severity"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "prohibited_items_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    }
                  ]
                },"promo_code_eligibility_rules": {
                  Row: {
                    "created_at": string,"description": string | null,"id": string,"promo_code_id": string,"rule_type": string,"rule_value": NonNullable<Json>
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"description"?: string | null,"id"?: string,"promo_code_id": string,"rule_type": string,"rule_value"?: NonNullable<Json>
                  }
                  Update: {
                    "created_at"?: string,"description"?: string | null,"id"?: string,"promo_code_id"?: string,"rule_type"?: string,"rule_value"?: NonNullable<Json>
                  }
                  Relationships: [
                    {
      foreignKeyName: "promo_code_eligibility_rules_promo_code_id_fkey"
      columns: ["promo_code_id"]
isOneToOne: false
      referencedRelation: "promo_code_active"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "promo_code_eligibility_rules_promo_code_id_fkey"
      columns: ["promo_code_id"]
isOneToOne: false
      referencedRelation: "promo_codes"
      referencedColumns: ["id"]
    }
                  ]
                },"promo_codes": {
                  Row: {
                    "applicable_cargo_type_ids": (string)[],"applicable_city_ids": (string)[],"applicable_vehicle_type_ids": (string)[],"code": string,"country_id": string | null,"created_at": string,"created_by": string | null,"currency_code": string | null,"description": string | null,"discount_type": string,"discount_value": number,"id": string,"is_active": boolean,"max_discount_amount": number | null,"min_purchase_amount": number,"name": string,"new_users_only": boolean,"per_user_redemption_limit": number,"total_redemption_limit": number | null,"updated_at": string,"valid_from": string,"valid_to": string
                  }
                  ComputedFields: never
                  Insert: {
                    "applicable_cargo_type_ids"?: (string)[],"applicable_city_ids"?: (string)[],"applicable_vehicle_type_ids"?: (string)[],"code": string,"country_id"?: string | null,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string | null,"description"?: string | null,"discount_type": string,"discount_value": number,"id"?: string,"is_active"?: boolean,"max_discount_amount"?: number | null,"min_purchase_amount"?: number,"name": string,"new_users_only"?: boolean,"per_user_redemption_limit"?: number,"total_redemption_limit"?: number | null,"updated_at"?: string,"valid_from": string,"valid_to": string
                  }
                  Update: {
                    "applicable_cargo_type_ids"?: (string)[],"applicable_city_ids"?: (string)[],"applicable_vehicle_type_ids"?: (string)[],"code"?: string,"country_id"?: string | null,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string | null,"description"?: string | null,"discount_type"?: string,"discount_value"?: number,"id"?: string,"is_active"?: boolean,"max_discount_amount"?: number | null,"min_purchase_amount"?: number,"name"?: string,"new_users_only"?: boolean,"per_user_redemption_limit"?: number,"total_redemption_limit"?: number | null,"updated_at"?: string,"valid_from"?: string,"valid_to"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "promo_codes_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "promo_codes_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "promo_codes_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    }
                  ]
                },"promo_redemptions": {
                  Row: {
                    "created_at": string,"currency_code": string,"discount_amount": number,"id": string,"job_id": string | null,"profile_id": string,"promo_code_id": string,"redeemed_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"currency_code": string,"discount_amount": number,"id"?: string,"job_id"?: string | null,"profile_id": string,"promo_code_id": string,"redeemed_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"currency_code"?: string,"discount_amount"?: number,"id"?: string,"job_id"?: string | null,"profile_id"?: string,"promo_code_id"?: string,"redeemed_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "promo_redemptions_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "promo_redemptions_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "promo_redemptions_promo_code_id_fkey"
      columns: ["promo_code_id"]
isOneToOne: false
      referencedRelation: "promo_code_active"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "promo_redemptions_promo_code_id_fkey"
      columns: ["promo_code_id"]
isOneToOne: false
      referencedRelation: "promo_codes"
      referencedColumns: ["id"]
    }
                  ]
                },"push_tokens": {
                  Row: {
                    "app_version": string | null,"created_at": string,"device_id": string,"id": string,"is_active": boolean,"last_used_at": string | null,"platform": string,"profile_id": string,"provider": string,"token": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "app_version"?: string | null,"created_at"?: string,"device_id": string,"id"?: string,"is_active"?: boolean,"last_used_at"?: string | null,"platform": string,"profile_id": string,"provider"?: string,"token": string,"updated_at"?: string
                  }
                  Update: {
                    "app_version"?: string | null,"created_at"?: string,"device_id"?: string,"id"?: string,"is_active"?: boolean,"last_used_at"?: string | null,"platform"?: string,"profile_id"?: string,"provider"?: string,"token"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "push_tokens_device_id_fkey"
      columns: ["device_id"]
isOneToOne: false
      referencedRelation: "user_devices"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "push_tokens_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"quote_requests": {
                  Row: {
                    "cargo_type_id": string | null,"cargo_volume_m3": number | null,"cargo_weight_kg": number | null,"city_id": string,"country_id": string,"created_at": string,"customer_id": string,"destination_address": string,"destination_location": unknown,"id": string,"metadata": NonNullable<Json>,"pickup_address": string,"pickup_location": unknown,"requested_at": string,"scheduled_at": string | null,"session_id": string | null,"stop_count": number,"updated_at": string,"vehicle_type_id": string,"waiting_minutes": number
                  }
                  ComputedFields: never
                  Insert: {
                    "cargo_type_id"?: string | null,"cargo_volume_m3"?: number | null,"cargo_weight_kg"?: number | null,"city_id": string,"country_id": string,"created_at"?: string,"customer_id": string,"destination_address": string,"destination_location": unknown,"id"?: string,"metadata"?: NonNullable<Json>,"pickup_address": string,"pickup_location": unknown,"requested_at"?: string,"scheduled_at"?: string | null,"session_id"?: string | null,"stop_count"?: number,"updated_at"?: string,"vehicle_type_id": string,"waiting_minutes"?: number
                  }
                  Update: {
                    "cargo_type_id"?: string | null,"cargo_volume_m3"?: number | null,"cargo_weight_kg"?: number | null,"city_id"?: string,"country_id"?: string,"created_at"?: string,"customer_id"?: string,"destination_address"?: string,"destination_location"?: unknown,"id"?: string,"metadata"?: NonNullable<Json>,"pickup_address"?: string,"pickup_location"?: unknown,"requested_at"?: string,"scheduled_at"?: string | null,"session_id"?: string | null,"stop_count"?: number,"updated_at"?: string,"vehicle_type_id"?: string,"waiting_minutes"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "quote_requests_cargo_type_id_fkey"
      columns: ["cargo_type_id"]
isOneToOne: false
      referencedRelation: "cargo_types"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quote_requests_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quote_requests_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quote_requests_customer_id_fkey"
      columns: ["customer_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quote_requests_vehicle_type_id_fkey"
      columns: ["vehicle_type_id"]
isOneToOne: false
      referencedRelation: "vehicle_types"
      referencedColumns: ["id"]
    }
                  ]
                },"quotes": {
                  Row: {
                    "base_fare": number,"cargo_surcharge": number,"created_at": string,"currency_code": string,"distance_charge": number,"distance_km": number,"equipment_surcharge": number,"estimated_duration_min": number,"expires_at": string,"id": string,"is_capped": boolean,"multi_stop_charge": number,"pricing_breakdown_snapshot": NonNullable<Json>,"pricing_plan_version_id": string,"promo_code_id": string | null,"promo_discount": number,"quote_request_id": string,"regulated_max_fare": number | null,"subtotal": number,"surge_multiplier": number,"time_charge": number,"time_multiplier": number,"total": number,"vat": number,"volume_surcharge": number,"waiting_charge": number,"weight_surcharge": number,"zone_multiplier": number
                  }
                  ComputedFields: never
                  Insert: {
                    "base_fare": number,"cargo_surcharge"?: number,"created_at"?: string,"currency_code": string,"distance_charge": number,"distance_km": number,"equipment_surcharge"?: number,"estimated_duration_min": number,"expires_at": string,"id"?: string,"is_capped"?: boolean,"multi_stop_charge"?: number,"pricing_breakdown_snapshot": NonNullable<Json>,"pricing_plan_version_id": string,"promo_code_id"?: string | null,"promo_discount"?: number,"quote_request_id": string,"regulated_max_fare"?: number | null,"subtotal": number,"surge_multiplier"?: number,"time_charge": number,"time_multiplier"?: number,"total": number,"vat": number,"volume_surcharge"?: number,"waiting_charge"?: number,"weight_surcharge"?: number,"zone_multiplier"?: number
                  }
                  Update: {
                    "base_fare"?: number,"cargo_surcharge"?: number,"created_at"?: string,"currency_code"?: string,"distance_charge"?: number,"distance_km"?: number,"equipment_surcharge"?: number,"estimated_duration_min"?: number,"expires_at"?: string,"id"?: string,"is_capped"?: boolean,"multi_stop_charge"?: number,"pricing_breakdown_snapshot"?: NonNullable<Json>,"pricing_plan_version_id"?: string,"promo_code_id"?: string | null,"promo_discount"?: number,"quote_request_id"?: string,"regulated_max_fare"?: number | null,"subtotal"?: number,"surge_multiplier"?: number,"time_charge"?: number,"time_multiplier"?: number,"total"?: number,"vat"?: number,"volume_surcharge"?: number,"waiting_charge"?: number,"weight_surcharge"?: number,"zone_multiplier"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "quotes_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "quotes_pricing_plan_version_id_fkey"
      columns: ["pricing_plan_version_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quotes_promo_code_id_fkey"
      columns: ["promo_code_id"]
isOneToOne: false
      referencedRelation: "promo_code_active"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quotes_promo_code_id_fkey"
      columns: ["promo_code_id"]
isOneToOne: false
      referencedRelation: "promo_codes"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quotes_quote_request_id_fkey"
      columns: ["quote_request_id"]
isOneToOne: false
      referencedRelation: "quote_requests"
      referencedColumns: ["id"]
    }
                  ]
                },"rating_categories": {
                  Row: {
                    "applies_to_role": Database["public"]['Enums']["user_role"],"code": string,"created_at": string,"description": string | null,"display_order": number,"id": string,"is_active": boolean,"name": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "applies_to_role": Database["public"]['Enums']["user_role"],"code": string,"created_at"?: string,"description"?: string | null,"display_order"?: number,"id"?: string,"is_active"?: boolean,"name": string,"updated_at"?: string
                  }
                  Update: {
                    "applies_to_role"?: Database["public"]['Enums']["user_role"],"code"?: string,"created_at"?: string,"description"?: string | null,"display_order"?: number,"id"?: string,"is_active"?: boolean,"name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"rating_reports": {
                  Row: {
                    "created_at": string,"id": string,"rating_id": string,"reason": string,"reported_by": string,"review_notes": string | null,"reviewed_at": string | null,"reviewed_by": string | null,"status": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"rating_id": string,"reason": string,"reported_by": string,"review_notes"?: string | null,"reviewed_at"?: string | null,"reviewed_by"?: string | null,"status"?: string,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"rating_id"?: string,"reason"?: string,"reported_by"?: string,"review_notes"?: string | null,"reviewed_at"?: string | null,"reviewed_by"?: string | null,"status"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "rating_reports_rating_id_fkey"
      columns: ["rating_id"]
isOneToOne: false
      referencedRelation: "ratings"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "rating_reports_reported_by_fkey"
      columns: ["reported_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "rating_reports_reviewed_by_fkey"
      columns: ["reviewed_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"ratings": {
                  Row: {
                    "comment": string | null,"created_at": string,"id": string,"is_anonymous": boolean,"job_id": string,"rated_profile_id": string,"rated_role": Database["public"]['Enums']["user_role"],"rater_profile_id": string,"rating_category_id": string,"score": number
                  }
                  ComputedFields: never
                  Insert: {
                    "comment"?: string | null,"created_at"?: string,"id"?: string,"is_anonymous"?: boolean,"job_id": string,"rated_profile_id": string,"rated_role": Database["public"]['Enums']["user_role"],"rater_profile_id": string,"rating_category_id": string,"score": number
                  }
                  Update: {
                    "comment"?: string | null,"created_at"?: string,"id"?: string,"is_anonymous"?: boolean,"job_id"?: string,"rated_profile_id"?: string,"rated_role"?: Database["public"]['Enums']["user_role"],"rater_profile_id"?: string,"rating_category_id"?: string,"score"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "ratings_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "ratings_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "ratings_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "ratings_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "ratings_rated_profile_id_fkey"
      columns: ["rated_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "ratings_rater_profile_id_fkey"
      columns: ["rater_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "ratings_rating_category_id_fkey"
      columns: ["rating_category_id"]
isOneToOne: false
      referencedRelation: "rating_categories"
      referencedColumns: ["id"]
    }
                  ]
                },"recurring_job_templates": {
                  Row: {
                    "business_account_id": string,"cargo_type_id": string | null,"created_at": string,"created_by": string,"default_cargo_volume_m3": number | null,"default_cargo_weight_kg": number | null,"description": string | null,"destination_address_id": string | null,"id": string,"is_active": boolean,"name": string,"pickup_address_id": string | null,"preferred_driver_id": string | null,"recurrence_rule": string,"time_of_day": string,"timezone": string,"updated_at": string,"vehicle_type_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "business_account_id": string,"cargo_type_id"?: string | null,"created_at"?: string,"created_by": string,"default_cargo_volume_m3"?: number | null,"default_cargo_weight_kg"?: number | null,"description"?: string | null,"destination_address_id"?: string | null,"id"?: string,"is_active"?: boolean,"name": string,"pickup_address_id"?: string | null,"preferred_driver_id"?: string | null,"recurrence_rule": string,"time_of_day": string,"timezone": string,"updated_at"?: string,"vehicle_type_id": string
                  }
                  Update: {
                    "business_account_id"?: string,"cargo_type_id"?: string | null,"created_at"?: string,"created_by"?: string,"default_cargo_volume_m3"?: number | null,"default_cargo_weight_kg"?: number | null,"description"?: string | null,"destination_address_id"?: string | null,"id"?: string,"is_active"?: boolean,"name"?: string,"pickup_address_id"?: string | null,"preferred_driver_id"?: string | null,"recurrence_rule"?: string,"time_of_day"?: string,"timezone"?: string,"updated_at"?: string,"vehicle_type_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "recurring_job_templates_business_account_id_fkey"
      columns: ["business_account_id"]
isOneToOne: false
      referencedRelation: "business_accounts"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "recurring_job_templates_cargo_type_id_fkey"
      columns: ["cargo_type_id"]
isOneToOne: false
      referencedRelation: "cargo_types"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "recurring_job_templates_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "recurring_job_templates_destination_address_id_fkey"
      columns: ["destination_address_id"]
isOneToOne: false
      referencedRelation: "addresses"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "recurring_job_templates_pickup_address_id_fkey"
      columns: ["pickup_address_id"]
isOneToOne: false
      referencedRelation: "addresses"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "recurring_job_templates_preferred_driver_id_fkey"
      columns: ["preferred_driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "recurring_job_templates_preferred_driver_id_fkey"
      columns: ["preferred_driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "recurring_job_templates_preferred_driver_id_fkey"
      columns: ["preferred_driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "recurring_job_templates_vehicle_type_id_fkey"
      columns: ["vehicle_type_id"]
isOneToOne: false
      referencedRelation: "vehicle_types"
      referencedColumns: ["id"]
    }
                  ]
                },"refunds": {
                  Row: {
                    "amount": number,"completed_at": string | null,"created_at": string,"currency_code": string,"failure_reason": string | null,"id": string,"job_id": string,"payment_id": string,"provider_reference": string | null,"reason": string,"refund_payment_id": string,"refund_type": string,"requested_by": string,"status": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"completed_at"?: string | null,"created_at"?: string,"currency_code": string,"failure_reason"?: string | null,"id"?: string,"job_id": string,"payment_id": string,"provider_reference"?: string | null,"reason": string,"refund_payment_id": string,"refund_type": string,"requested_by": string,"status"?: string,"updated_at"?: string
                  }
                  Update: {
                    "amount"?: number,"completed_at"?: string | null,"created_at"?: string,"currency_code"?: string,"failure_reason"?: string | null,"id"?: string,"job_id"?: string,"payment_id"?: string,"provider_reference"?: string | null,"reason"?: string,"refund_payment_id"?: string,"refund_type"?: string,"requested_by"?: string,"status"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "refunds_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "refunds_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "refunds_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "refunds_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "refunds_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "refunds_payment_id_fkey"
      columns: ["payment_id"]
isOneToOne: false
      referencedRelation: "payment_reconciliation"
      referencedColumns: ["payment_id"]
    },{
      foreignKeyName: "refunds_payment_id_fkey"
      columns: ["payment_id"]
isOneToOne: false
      referencedRelation: "payments"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "refunds_refund_payment_id_fkey"
      columns: ["refund_payment_id"]
isOneToOne: false
      referencedRelation: "payment_reconciliation"
      referencedColumns: ["payment_id"]
    },{
      foreignKeyName: "refunds_refund_payment_id_fkey"
      columns: ["refund_payment_id"]
isOneToOne: false
      referencedRelation: "payments"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "refunds_requested_by_fkey"
      columns: ["requested_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"regions": {
                  Row: {
                    "code": string | null,"country_id": string,"created_at": string,"id": string,"is_active": boolean,"name": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "code"?: string | null,"country_id": string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"name": string,"updated_at"?: string
                  }
                  Update: {
                    "code"?: string | null,"country_id"?: string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "regions_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    }
                  ]
                },"regulated_tariff_bands": {
                  Row: {
                    "band_type": string,"created_at": string,"display_order": number,"id": string,"max_fare": number,"max_value": number | null,"min_fare": number,"min_value": number,"regulated_tariff_id": string,"value_unit": string
                  }
                  ComputedFields: never
                  Insert: {
                    "band_type": string,"created_at"?: string,"display_order"?: number,"id"?: string,"max_fare": number,"max_value"?: number | null,"min_fare": number,"min_value": number,"regulated_tariff_id": string,"value_unit": string
                  }
                  Update: {
                    "band_type"?: string,"created_at"?: string,"display_order"?: number,"id"?: string,"max_fare"?: number,"max_value"?: number | null,"min_fare"?: number,"min_value"?: number,"regulated_tariff_id"?: string,"value_unit"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "regulated_tariff_bands_regulated_tariff_id_fkey"
      columns: ["regulated_tariff_id"]
isOneToOne: false
      referencedRelation: "regulated_tariff_bands_summary"
      referencedColumns: ["tariff_id"]
    },{
      foreignKeyName: "regulated_tariff_bands_regulated_tariff_id_fkey"
      columns: ["regulated_tariff_id"]
isOneToOne: false
      referencedRelation: "regulated_tariffs"
      referencedColumns: ["id"]
    }
                  ]
                },"regulated_tariffs": {
                  Row: {
                    "approval_date": string,"approval_reference": string,"country_id": string,"created_at": string,"currency_code": string,"effective_from": string,"effective_to": string | null,"id": string,"is_active": boolean,"name": string,"notes": string | null,"published_gazette_date": string | null,"regulatory_body": string,"source_document_url": string | null,"tariff_structure": string,"updated_at": string,"vehicle_type_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "approval_date": string,"approval_reference": string,"country_id": string,"created_at"?: string,"currency_code": string,"effective_from": string,"effective_to"?: string | null,"id"?: string,"is_active"?: boolean,"name": string,"notes"?: string | null,"published_gazette_date"?: string | null,"regulatory_body": string,"source_document_url"?: string | null,"tariff_structure": string,"updated_at"?: string,"vehicle_type_id"?: string | null
                  }
                  Update: {
                    "approval_date"?: string,"approval_reference"?: string,"country_id"?: string,"created_at"?: string,"currency_code"?: string,"effective_from"?: string,"effective_to"?: string | null,"id"?: string,"is_active"?: boolean,"name"?: string,"notes"?: string | null,"published_gazette_date"?: string | null,"regulatory_body"?: string,"source_document_url"?: string | null,"tariff_structure"?: string,"updated_at"?: string,"vehicle_type_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "regulated_tariffs_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "regulated_tariffs_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "regulated_tariffs_vehicle_type_id_fkey"
      columns: ["vehicle_type_id"]
isOneToOne: false
      referencedRelation: "vehicle_types"
      referencedColumns: ["id"]
    }
                  ]
                },"retention_policies": {
                  Row: {
                    "action": string,"created_at": string,"id": string,"is_active": boolean,"last_run_at": string | null,"last_run_rows_affected": number | null,"notes": string | null,"retention_period": string,"table_name": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "action": string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"last_run_at"?: string | null,"last_run_rows_affected"?: number | null,"notes"?: string | null,"retention_period": string,"table_name": string,"updated_at"?: string
                  }
                  Update: {
                    "action"?: string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"last_run_at"?: string | null,"last_run_rows_affected"?: number | null,"notes"?: string | null,"retention_period"?: string,"table_name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"saved_addresses": {
                  Row: {
                    "address_id": string,"created_at": string,"id": string,"is_default": boolean,"label": string | null,"profile_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "address_id": string,"created_at"?: string,"id"?: string,"is_default"?: boolean,"label"?: string | null,"profile_id": string,"updated_at"?: string
                  }
                  Update: {
                    "address_id"?: string,"created_at"?: string,"id"?: string,"is_default"?: boolean,"label"?: string | null,"profile_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "saved_addresses_address_id_fkey"
      columns: ["address_id"]
isOneToOne: false
      referencedRelation: "addresses"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "saved_addresses_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"scheduled_jobs": {
                  Row: {
                    "created_at": string,"error_reason": string | null,"generated_at": string | null,"id": string,"job_id": string | null,"quote_request_id": string | null,"scheduled_for": string,"status": string,"template_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"error_reason"?: string | null,"generated_at"?: string | null,"id"?: string,"job_id"?: string | null,"quote_request_id"?: string | null,"scheduled_for": string,"status"?: string,"template_id": string,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"error_reason"?: string | null,"generated_at"?: string | null,"id"?: string,"job_id"?: string | null,"quote_request_id"?: string | null,"scheduled_for"?: string,"status"?: string,"template_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "scheduled_jobs_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "scheduled_jobs_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "scheduled_jobs_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "scheduled_jobs_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "scheduled_jobs_quote_request_id_fkey"
      columns: ["quote_request_id"]
isOneToOne: false
      referencedRelation: "quote_requests"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "scheduled_jobs_template_id_fkey"
      columns: ["template_id"]
isOneToOne: false
      referencedRelation: "recurring_job_templates"
      referencedColumns: ["id"]
    }
                  ]
                },"service_zones": {
                  Row: {
                    "boundary": unknown,"centroid": unknown,"city_id": string,"created_at": string,"id": string,"is_active": boolean,"metadata": NonNullable<Json>,"name": string,"updated_at": string,"zone_type": string
                  }
                  ComputedFields: never
                  Insert: {
                    "boundary": unknown,"centroid": unknown,"city_id": string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"metadata"?: NonNullable<Json>,"name": string,"updated_at"?: string,"zone_type": string
                  }
                  Update: {
                    "boundary"?: unknown,"centroid"?: unknown,"city_id"?: string,"created_at"?: string,"id"?: string,"is_active"?: boolean,"metadata"?: NonNullable<Json>,"name"?: string,"updated_at"?: string,"zone_type"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "service_zones_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    }
                  ]
                },"support_categories": {
                  Row: {
                    "code": string,"country_id": string | null,"created_at": string,"description": string | null,"display_order": number,"id": string,"is_active": boolean,"name": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "code": string,"country_id"?: string | null,"created_at"?: string,"description"?: string | null,"display_order"?: number,"id"?: string,"is_active"?: boolean,"name": string,"updated_at"?: string
                  }
                  Update: {
                    "code"?: string,"country_id"?: string | null,"created_at"?: string,"description"?: string | null,"display_order"?: number,"id"?: string,"is_active"?: boolean,"name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "support_categories_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    }
                  ]
                },"support_ticket_messages": {
                  Row: {
                    "attachments": (string)[],"created_at": string,"id": number,"is_internal_note": boolean,"message": string,"sender_profile_id": string,"ticket_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "attachments"?: (string)[],"created_at"?: string,"id"?: never,"is_internal_note"?: boolean,"message": string,"sender_profile_id": string,"ticket_id": string
                  }
                  Update: {
                    "attachments"?: (string)[],"created_at"?: string,"id"?: never,"is_internal_note"?: boolean,"message"?: string,"sender_profile_id"?: string,"ticket_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "support_ticket_messages_sender_profile_id_fkey"
      columns: ["sender_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "support_ticket_messages_ticket_id_fkey"
      columns: ["ticket_id"]
isOneToOne: false
      referencedRelation: "support_tickets"
      referencedColumns: ["id"]
    }
                  ]
                },"support_tickets": {
                  Row: {
                    "assigned_to": string | null,"category_id": string,"closed_at": string | null,"country_id": string,"created_at": string,"id": string,"opened_by": string,"priority": string,"related_dispute_id": string | null,"related_job_id": string | null,"resolved_at": string | null,"satisfaction_rating": number | null,"sla_due_at": string | null,"status": string,"subject": string,"ticket_number": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "assigned_to"?: string | null,"category_id": string,"closed_at"?: string | null,"country_id": string,"created_at"?: string,"id"?: string,"opened_by": string,"priority"?: string,"related_dispute_id"?: string | null,"related_job_id"?: string | null,"resolved_at"?: string | null,"satisfaction_rating"?: number | null,"sla_due_at"?: string | null,"status"?: string,"subject": string,"ticket_number": string,"updated_at"?: string
                  }
                  Update: {
                    "assigned_to"?: string | null,"category_id"?: string,"closed_at"?: string | null,"country_id"?: string,"created_at"?: string,"id"?: string,"opened_by"?: string,"priority"?: string,"related_dispute_id"?: string | null,"related_job_id"?: string | null,"resolved_at"?: string | null,"satisfaction_rating"?: number | null,"sla_due_at"?: string | null,"status"?: string,"subject"?: string,"ticket_number"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "support_tickets_assigned_to_fkey"
      columns: ["assigned_to"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "support_tickets_category_id_fkey"
      columns: ["category_id"]
isOneToOne: false
      referencedRelation: "support_categories"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "support_tickets_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "support_tickets_opened_by_fkey"
      columns: ["opened_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "support_tickets_related_dispute_id_fkey"
      columns: ["related_dispute_id"]
isOneToOne: false
      referencedRelation: "dispute_summary"
      referencedColumns: ["dispute_id"]
    },{
      foreignKeyName: "support_tickets_related_dispute_id_fkey"
      columns: ["related_dispute_id"]
isOneToOne: false
      referencedRelation: "disputes"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "support_tickets_related_job_id_fkey"
      columns: ["related_job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "support_tickets_related_job_id_fkey"
      columns: ["related_job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "support_tickets_related_job_id_fkey"
      columns: ["related_job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "support_tickets_related_job_id_fkey"
      columns: ["related_job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"surge_multipliers": {
                  Row: {
                    "city_id": string,"created_at": string,"created_by": string | null,"ends_at": string,"id": string,"multiplier": number,"reason": string | null,"service_zone_id": string | null,"starts_at": string,"updated_at": string,"vehicle_type_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "city_id": string,"created_at"?: string,"created_by"?: string | null,"ends_at": string,"id"?: string,"multiplier": number,"reason"?: string | null,"service_zone_id"?: string | null,"starts_at": string,"updated_at"?: string,"vehicle_type_id"?: string | null
                  }
                  Update: {
                    "city_id"?: string,"created_at"?: string,"created_by"?: string | null,"ends_at"?: string,"id"?: string,"multiplier"?: number,"reason"?: string | null,"service_zone_id"?: string | null,"starts_at"?: string,"updated_at"?: string,"vehicle_type_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "surge_multipliers_city_id_fkey"
      columns: ["city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "surge_multipliers_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "surge_multipliers_service_zone_id_fkey"
      columns: ["service_zone_id"]
isOneToOne: false
      referencedRelation: "service_zones"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "surge_multipliers_vehicle_type_id_fkey"
      columns: ["vehicle_type_id"]
isOneToOne: false
      referencedRelation: "vehicle_types"
      referencedColumns: ["id"]
    }
                  ]
                },"tax_rates": {
                  Row: {
                    "applies_to": string,"country_id": string,"created_at": string,"effective_from": string,"effective_to": string | null,"id": string,"is_active": boolean,"name": string,"notes": string | null,"rate": number,"tax_type": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "applies_to": string,"country_id": string,"created_at"?: string,"effective_from": string,"effective_to"?: string | null,"id"?: string,"is_active"?: boolean,"name": string,"notes"?: string | null,"rate": number,"tax_type": string,"updated_at"?: string
                  }
                  Update: {
                    "applies_to"?: string,"country_id"?: string,"created_at"?: string,"effective_from"?: string,"effective_to"?: string | null,"id"?: string,"is_active"?: boolean,"name"?: string,"notes"?: string | null,"rate"?: number,"tax_type"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "tax_rates_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    }
                  ]
                },"user_devices": {
                  Row: {
                    "app_version": string | null,"created_at": string,"device_id": string,"device_name": string | null,"device_type": string,"id": string,"is_active": boolean,"last_seen_at": string,"os_version": string | null,"profile_id": string,"push_provider": string | null,"push_token": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "app_version"?: string | null,"created_at"?: string,"device_id": string,"device_name"?: string | null,"device_type": string,"id"?: string,"is_active"?: boolean,"last_seen_at"?: string,"os_version"?: string | null,"profile_id": string,"push_provider"?: string | null,"push_token"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "app_version"?: string | null,"created_at"?: string,"device_id"?: string,"device_name"?: string | null,"device_type"?: string,"id"?: string,"is_active"?: boolean,"last_seen_at"?: string,"os_version"?: string | null,"profile_id"?: string,"push_provider"?: string | null,"push_token"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "user_devices_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"user_referrals": {
                  Row: {
                    "completed_at": string | null,"created_at": string,"id": string,"referral_code": string,"referred_profile_id": string | null,"referrer_profile_id": string,"reward_amount": number | null,"reward_granted": boolean,"status": string
                  }
                  ComputedFields: never
                  Insert: {
                    "completed_at"?: string | null,"created_at"?: string,"id"?: string,"referral_code": string,"referred_profile_id"?: string | null,"referrer_profile_id": string,"reward_amount"?: number | null,"reward_granted"?: boolean,"status"?: string
                  }
                  Update: {
                    "completed_at"?: string | null,"created_at"?: string,"id"?: string,"referral_code"?: string,"referred_profile_id"?: string | null,"referrer_profile_id"?: string,"reward_amount"?: number | null,"reward_granted"?: boolean,"status"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "user_referrals_referred_profile_id_fkey"
      columns: ["referred_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "user_referrals_referrer_profile_id_fkey"
      columns: ["referrer_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"user_sessions": {
                  Row: {
                    "created_at": string,"device_id": string | null,"expires_at": string,"id": string,"ip_address": unknown,"profile_id": string,"revoked_at": string | null,"revoked_reason": string | null,"session_token_hash": string,"user_agent": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"device_id"?: string | null,"expires_at": string,"id"?: string,"ip_address"?: unknown,"profile_id": string,"revoked_at"?: string | null,"revoked_reason"?: string | null,"session_token_hash": string,"user_agent"?: string | null
                  }
                  Update: {
                    "created_at"?: string,"device_id"?: string | null,"expires_at"?: string,"id"?: string,"ip_address"?: unknown,"profile_id"?: string,"revoked_at"?: string | null,"revoked_reason"?: string | null,"session_token_hash"?: string,"user_agent"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "user_sessions_device_id_fkey"
      columns: ["device_id"]
isOneToOne: false
      referencedRelation: "user_devices"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "user_sessions_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"vehicle_assignments": {
                  Row: {
                    "assigned_at": string,"assigned_by": string | null,"created_at": string,"driver_id": string,"id": string,"is_active": boolean,"unassign_reason": string | null,"unassigned_at": string | null,"updated_at": string,"vehicle_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "assigned_at"?: string,"assigned_by"?: string | null,"created_at"?: string,"driver_id": string,"id"?: string,"is_active"?: boolean,"unassign_reason"?: string | null,"unassigned_at"?: string | null,"updated_at"?: string,"vehicle_id": string
                  }
                  Update: {
                    "assigned_at"?: string,"assigned_by"?: string | null,"created_at"?: string,"driver_id"?: string,"id"?: string,"is_active"?: boolean,"unassign_reason"?: string | null,"unassigned_at"?: string | null,"updated_at"?: string,"vehicle_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "vehicle_assignments_assigned_by_fkey"
      columns: ["assigned_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicle_assignments_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "vehicle_assignments_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "vehicle_assignments_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicle_assignments_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_public_view"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicle_assignments_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_verification_summary"
      referencedColumns: ["vehicle_id"]
    },{
      foreignKeyName: "vehicle_assignments_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicles"
      referencedColumns: ["id"]
    }
                  ]
                },"vehicle_documents": {
                  Row: {
                    "created_at": string,"document_number": string | null,"document_type_id": string,"expires_at": string | null,"file_mime_type": string | null,"file_path": string,"file_size_bytes": number | null,"id": string,"is_current": boolean,"issued_at": string | null,"rejection_reason": string | null,"superseded_by": string | null,"updated_at": string,"vehicle_id": string,"verification_status": Database["public"]['Enums']["driver_verification_status"],"verified_at": string | null,"verified_by": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"document_number"?: string | null,"document_type_id": string,"expires_at"?: string | null,"file_mime_type"?: string | null,"file_path": string,"file_size_bytes"?: number | null,"id"?: string,"is_current"?: boolean,"issued_at"?: string | null,"rejection_reason"?: string | null,"superseded_by"?: string | null,"updated_at"?: string,"vehicle_id": string,"verification_status"?: Database["public"]['Enums']["driver_verification_status"],"verified_at"?: string | null,"verified_by"?: string | null
                  }
                  Update: {
                    "created_at"?: string,"document_number"?: string | null,"document_type_id"?: string,"expires_at"?: string | null,"file_mime_type"?: string | null,"file_path"?: string,"file_size_bytes"?: number | null,"id"?: string,"is_current"?: boolean,"issued_at"?: string | null,"rejection_reason"?: string | null,"superseded_by"?: string | null,"updated_at"?: string,"vehicle_id"?: string,"verification_status"?: Database["public"]['Enums']["driver_verification_status"],"verified_at"?: string | null,"verified_by"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "vehicle_documents_document_type_id_fkey"
      columns: ["document_type_id"]
isOneToOne: false
      referencedRelation: "document_types"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicle_documents_superseded_by_fkey"
      columns: ["superseded_by"]
isOneToOne: false
      referencedRelation: "vehicle_documents"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicle_documents_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_public_view"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicle_documents_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_verification_summary"
      referencedColumns: ["vehicle_id"]
    },{
      foreignKeyName: "vehicle_documents_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicle_documents_verified_by_fkey"
      columns: ["verified_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"vehicle_equipment": {
                  Row: {
                    "condition": string | null,"created_at": string,"equipment_id": string,"id": string,"last_verified_at": string | null,"quantity": number,"updated_at": string,"vehicle_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "condition"?: string | null,"created_at"?: string,"equipment_id": string,"id"?: string,"last_verified_at"?: string | null,"quantity"?: number,"updated_at"?: string,"vehicle_id": string
                  }
                  Update: {
                    "condition"?: string | null,"created_at"?: string,"equipment_id"?: string,"id"?: string,"last_verified_at"?: string | null,"quantity"?: number,"updated_at"?: string,"vehicle_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "vehicle_equipment_equipment_id_fkey"
      columns: ["equipment_id"]
isOneToOne: false
      referencedRelation: "vehicle_equipment_catalog"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicle_equipment_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_public_view"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicle_equipment_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_verification_summary"
      referencedColumns: ["vehicle_id"]
    },{
      foreignKeyName: "vehicle_equipment_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicles"
      referencedColumns: ["id"]
    }
                  ]
                },"vehicle_equipment_catalog": {
                  Row: {
                    "category": string | null,"code": string,"created_at": string,"description": string | null,"icon_url": string | null,"id": string,"is_active": boolean,"name": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "category"?: string | null,"code": string,"created_at"?: string,"description"?: string | null,"icon_url"?: string | null,"id"?: string,"is_active"?: boolean,"name": string,"updated_at"?: string
                  }
                  Update: {
                    "category"?: string | null,"code"?: string,"created_at"?: string,"description"?: string | null,"icon_url"?: string | null,"id"?: string,"is_active"?: boolean,"name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"vehicle_makes": {
                  Row: {
                    "country_of_origin": string | null,"created_at": string,"id": string,"is_active": boolean,"name": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "country_of_origin"?: string | null,"created_at"?: string,"id"?: string,"is_active"?: boolean,"name": string,"updated_at"?: string
                  }
                  Update: {
                    "country_of_origin"?: string | null,"created_at"?: string,"id"?: string,"is_active"?: boolean,"name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"vehicle_models": {
                  Row: {
                    "created_at": string,"id": string,"is_active": boolean,"make_id": string,"name": string,"updated_at": string,"vehicle_type_id": string | null,"year_end": number | null,"year_start": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"is_active"?: boolean,"make_id": string,"name": string,"updated_at"?: string,"vehicle_type_id"?: string | null,"year_end"?: number | null,"year_start"?: number | null
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"is_active"?: boolean,"make_id"?: string,"name"?: string,"updated_at"?: string,"vehicle_type_id"?: string | null,"year_end"?: number | null,"year_start"?: number | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "vehicle_models_make_id_fkey"
      columns: ["make_id"]
isOneToOne: false
      referencedRelation: "vehicle_makes"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicle_models_vehicle_type_id_fkey"
      columns: ["vehicle_type_id"]
isOneToOne: false
      referencedRelation: "vehicle_types"
      referencedColumns: ["id"]
    }
                  ]
                },"vehicle_types": {
                  Row: {
                    "capacity_kg_max": number,"capacity_kg_min": number,"capacity_m3_max": number | null,"capacity_m3_min": number | null,"code": string,"country_id": string | null,"created_at": string,"description": string | null,"display_order": number,"icon_url": string | null,"id": string,"is_active": boolean,"max_dimensions_cm": Json | null,"name": string,"number_of_wheels": number | null,"requires_equipment": (string)[] | null,"requires_special_licence": boolean,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "capacity_kg_max": number,"capacity_kg_min": number,"capacity_m3_max"?: number | null,"capacity_m3_min"?: number | null,"code": string,"country_id"?: string | null,"created_at"?: string,"description"?: string | null,"display_order"?: number,"icon_url"?: string | null,"id"?: string,"is_active"?: boolean,"max_dimensions_cm"?: Json | null,"name": string,"number_of_wheels"?: number | null,"requires_equipment"?: (string)[] | null,"requires_special_licence"?: boolean,"updated_at"?: string
                  }
                  Update: {
                    "capacity_kg_max"?: number,"capacity_kg_min"?: number,"capacity_m3_max"?: number | null,"capacity_m3_min"?: number | null,"code"?: string,"country_id"?: string | null,"created_at"?: string,"description"?: string | null,"display_order"?: number,"icon_url"?: string | null,"id"?: string,"is_active"?: boolean,"max_dimensions_cm"?: Json | null,"name"?: string,"number_of_wheels"?: number | null,"requires_equipment"?: (string)[] | null,"requires_special_licence"?: boolean,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "vehicle_types_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    }
                  ]
                },"vehicles": {
                  Row: {
                    "capacity_kg": number,"capacity_m3": number | null,"chassis_number": string | null,"color": string | null,"country_id": string,"created_at": string,"dimensions_cm": Json | null,"engine_number": string | null,"home_city_id": string | null,"id": string,"is_active": boolean,"make_id": string | null,"model_id": string | null,"owner_business_account_id": string | null,"owner_fleet_id": string | null,"owner_profile_id": string | null,"owner_type": string,"photo_urls": (string)[],"primary_driver_id": string | null,"registration_country_id": string,"registration_number": string,"rejection_reason": string | null,"updated_at": string,"vehicle_type_id": string,"verification_status": Database["public"]['Enums']["driver_verification_status"],"verified_at": string | null,"verified_by": string | null,"year": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "capacity_kg": number,"capacity_m3"?: number | null,"chassis_number"?: string | null,"color"?: string | null,"country_id": string,"created_at"?: string,"dimensions_cm"?: Json | null,"engine_number"?: string | null,"home_city_id"?: string | null,"id"?: string,"is_active"?: boolean,"make_id"?: string | null,"model_id"?: string | null,"owner_business_account_id"?: string | null,"owner_fleet_id"?: string | null,"owner_profile_id"?: string | null,"owner_type": string,"photo_urls"?: (string)[],"primary_driver_id"?: string | null,"registration_country_id": string,"registration_number": string,"rejection_reason"?: string | null,"updated_at"?: string,"vehicle_type_id": string,"verification_status"?: Database["public"]['Enums']["driver_verification_status"],"verified_at"?: string | null,"verified_by"?: string | null,"year"?: number | null
                  }
                  Update: {
                    "capacity_kg"?: number,"capacity_m3"?: number | null,"chassis_number"?: string | null,"color"?: string | null,"country_id"?: string,"created_at"?: string,"dimensions_cm"?: Json | null,"engine_number"?: string | null,"home_city_id"?: string | null,"id"?: string,"is_active"?: boolean,"make_id"?: string | null,"model_id"?: string | null,"owner_business_account_id"?: string | null,"owner_fleet_id"?: string | null,"owner_profile_id"?: string | null,"owner_type"?: string,"photo_urls"?: (string)[],"primary_driver_id"?: string | null,"registration_country_id"?: string,"registration_number"?: string,"rejection_reason"?: string | null,"updated_at"?: string,"vehicle_type_id"?: string,"verification_status"?: Database["public"]['Enums']["driver_verification_status"],"verified_at"?: string | null,"verified_by"?: string | null,"year"?: number | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "vehicles_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicles_home_city_id_fkey"
      columns: ["home_city_id"]
isOneToOne: false
      referencedRelation: "cities"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicles_make_id_fkey"
      columns: ["make_id"]
isOneToOne: false
      referencedRelation: "vehicle_makes"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicles_model_id_fkey"
      columns: ["model_id"]
isOneToOne: false
      referencedRelation: "vehicle_models"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicles_owner_business_account_id_fkey"
      columns: ["owner_business_account_id"]
isOneToOne: false
      referencedRelation: "business_accounts"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicles_owner_fleet_id_fkey"
      columns: ["owner_fleet_id"]
isOneToOne: false
      referencedRelation: "active_fleet_roster"
      referencedColumns: ["fleet_id"]
    },{
      foreignKeyName: "vehicles_owner_fleet_id_fkey"
      columns: ["owner_fleet_id"]
isOneToOne: false
      referencedRelation: "fleets"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicles_owner_profile_id_fkey"
      columns: ["owner_profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicles_primary_driver_id_fkey"
      columns: ["primary_driver_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicles_registration_country_id_fkey"
      columns: ["registration_country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicles_vehicle_type_id_fkey"
      columns: ["vehicle_type_id"]
isOneToOne: false
      referencedRelation: "vehicle_types"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "vehicles_verified_by_fkey"
      columns: ["verified_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"verification_checklist_templates": {
                  Row: {
                    "country_id": string,"created_at": string,"description": string | null,"id": string,"is_active": boolean,"optional_document_codes": (string)[],"request_type": string,"required_document_codes": (string)[],"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "country_id": string,"created_at"?: string,"description"?: string | null,"id"?: string,"is_active"?: boolean,"optional_document_codes"?: (string)[],"request_type": string,"required_document_codes"?: (string)[],"updated_at"?: string
                  }
                  Update: {
                    "country_id"?: string,"created_at"?: string,"description"?: string | null,"id"?: string,"is_active"?: boolean,"optional_document_codes"?: (string)[],"request_type"?: string,"required_document_codes"?: (string)[],"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "verification_checklist_templates_country_id_fkey"
      columns: ["country_id"]
isOneToOne: false
      referencedRelation: "countries"
      referencedColumns: ["id"]
    }
                  ]
                },"verification_history": {
                  Row: {
                    "action": string,"actor_id": string | null,"business_account_id": string | null,"created_at": string,"driver_document_id": string | null,"driver_id": string | null,"id": number,"notes": string | null,"vehicle_document_id": string | null,"vehicle_id": string | null,"verification_request_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "action": string,"actor_id"?: string | null,"business_account_id"?: string | null,"created_at"?: string,"driver_document_id"?: string | null,"driver_id"?: string | null,"id"?: never,"notes"?: string | null,"vehicle_document_id"?: string | null,"vehicle_id"?: string | null,"verification_request_id"?: string | null
                  }
                  Update: {
                    "action"?: string,"actor_id"?: string | null,"business_account_id"?: string | null,"created_at"?: string,"driver_document_id"?: string | null,"driver_id"?: string | null,"id"?: never,"notes"?: string | null,"vehicle_document_id"?: string | null,"vehicle_id"?: string | null,"verification_request_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "verification_history_actor_id_fkey"
      columns: ["actor_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "verification_history_business_account_id_fkey"
      columns: ["business_account_id"]
isOneToOne: false
      referencedRelation: "business_accounts"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "verification_history_driver_document_id_fkey"
      columns: ["driver_document_id"]
isOneToOne: false
      referencedRelation: "driver_documents"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "verification_history_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "verification_history_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "verification_history_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "verification_history_vehicle_document_id_fkey"
      columns: ["vehicle_document_id"]
isOneToOne: false
      referencedRelation: "vehicle_documents"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "verification_history_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_public_view"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "verification_history_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_verification_summary"
      referencedColumns: ["vehicle_id"]
    },{
      foreignKeyName: "verification_history_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "verification_history_verification_request_id_fkey"
      columns: ["verification_request_id"]
isOneToOne: false
      referencedRelation: "verification_requests"
      referencedColumns: ["id"]
    }
                  ]
                },"verification_requests": {
                  Row: {
                    "assigned_at": string | null,"assigned_to": string | null,"business_account_id": string | null,"created_at": string,"decided_at": string | null,"decision_notes": string | null,"driver_id": string | null,"id": string,"priority": string,"request_type": string,"requested_by": string,"reviewed_at": string | null,"sla_due_at": string | null,"status": string,"submitted_at": string,"updated_at": string,"vehicle_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "assigned_at"?: string | null,"assigned_to"?: string | null,"business_account_id"?: string | null,"created_at"?: string,"decided_at"?: string | null,"decision_notes"?: string | null,"driver_id"?: string | null,"id"?: string,"priority"?: string,"request_type": string,"requested_by": string,"reviewed_at"?: string | null,"sla_due_at"?: string | null,"status"?: string,"submitted_at"?: string,"updated_at"?: string,"vehicle_id"?: string | null
                  }
                  Update: {
                    "assigned_at"?: string | null,"assigned_to"?: string | null,"business_account_id"?: string | null,"created_at"?: string,"decided_at"?: string | null,"decision_notes"?: string | null,"driver_id"?: string | null,"id"?: string,"priority"?: string,"request_type"?: string,"requested_by"?: string,"reviewed_at"?: string | null,"sla_due_at"?: string | null,"status"?: string,"submitted_at"?: string,"updated_at"?: string,"vehicle_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "verification_requests_assigned_to_fkey"
      columns: ["assigned_to"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "verification_requests_business_account_id_fkey"
      columns: ["business_account_id"]
isOneToOne: false
      referencedRelation: "business_accounts"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "verification_requests_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "verification_requests_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "verification_requests_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "verification_requests_requested_by_fkey"
      columns: ["requested_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "verification_requests_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_public_view"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "verification_requests_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicle_verification_summary"
      referencedColumns: ["vehicle_id"]
    },{
      foreignKeyName: "verification_requests_vehicle_id_fkey"
      columns: ["vehicle_id"]
isOneToOne: false
      referencedRelation: "vehicles"
      referencedColumns: ["id"]
    }
                  ]
                },"wallet_transactions": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "wallet_transactions_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "wallet_transactions_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "wallet_transactions_wallet_id_fkey"
      columns: ["wallet_id"]
isOneToOne: false
      referencedRelation: "wallet_balance_current"
      referencedColumns: ["wallet_id"]
    },{
      foreignKeyName: "wallet_transactions_wallet_id_fkey"
      columns: ["wallet_id"]
isOneToOne: false
      referencedRelation: "wallets"
      referencedColumns: ["id"]
    }
                  ]
                },"wallet_transactions_2026_10": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallet_transactions_2026_11": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallet_transactions_2026_12": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallet_transactions_2027_01": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallet_transactions_2027_02": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallet_transactions_2027_03": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallet_transactions_2027_04": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallet_transactions_2027_05": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallet_transactions_2027_06": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallet_transactions_2027_07": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallet_transactions_2027_08": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallet_transactions_2027_09": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallet_transactions_default": {
                  Row: {
                    "amount": number,"balance_after": number,"created_at": string,"created_by": string | null,"currency_code": string,"description": string | null,"id": number,"metadata": NonNullable<Json>,"reference_id": string | null,"reference_type": string | null,"transaction_type": string,"wallet_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code": string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type": string,"wallet_id": string
                  }
                  Update: {
                    "amount"?: number,"balance_after"?: number,"created_at"?: string,"created_by"?: string | null,"currency_code"?: string,"description"?: string | null,"id"?: never,"metadata"?: NonNullable<Json>,"reference_id"?: string | null,"reference_type"?: string | null,"transaction_type"?: string,"wallet_id"?: string
                  }
                  Relationships: [
                    
                  ]
                },"wallets": {
                  Row: {
                    "cached_balance": number,"created_at": string,"currency_code": string,"frozen_reason": string | null,"id": string,"is_frozen": boolean,"profile_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "cached_balance"?: number,"created_at"?: string,"currency_code": string,"frozen_reason"?: string | null,"id"?: string,"is_frozen"?: boolean,"profile_id": string,"updated_at"?: string
                  }
                  Update: {
                    "cached_balance"?: number,"created_at"?: string,"currency_code"?: string,"frozen_reason"?: string | null,"id"?: string,"is_frozen"?: boolean,"profile_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "wallets_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "wallets_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"zone_metrics": {
                  Row: {
                    "avg_eta_minutes": number | null,"computed_at": string,"demand_score": number | null,"id": number,"jobs_fulfilled": number,"jobs_requested": number,"metric_date": string,"service_zone_id": string,"supply_available_minutes": number | null,"surge_multiplier_avg": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "avg_eta_minutes"?: number | null,"computed_at"?: string,"demand_score"?: number | null,"id"?: never,"jobs_fulfilled"?: number,"jobs_requested"?: number,"metric_date": string,"service_zone_id": string,"supply_available_minutes"?: number | null,"surge_multiplier_avg"?: number | null
                  }
                  Update: {
                    "avg_eta_minutes"?: number | null,"computed_at"?: string,"demand_score"?: number | null,"id"?: never,"jobs_fulfilled"?: number,"jobs_requested"?: number,"metric_date"?: string,"service_zone_id"?: string,"supply_available_minutes"?: number | null,"surge_multiplier_avg"?: number | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "zone_metrics_service_zone_id_fkey"
      columns: ["service_zone_id"]
isOneToOne: false
      referencedRelation: "service_zones"
      referencedColumns: ["id"]
    }
                  ]
                },"zone_pricing_override_resolution": {
                  Row: {
                    "created_at": string,"id": string,"pricing_plan_version_id": string,"resolved_at": string,"resolved_by": string | null,"zone_pricing_override_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"pricing_plan_version_id": string,"resolved_at"?: string,"resolved_by"?: string | null,"zone_pricing_override_id": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"pricing_plan_version_id"?: string,"resolved_at"?: string,"resolved_by"?: string | null,"zone_pricing_override_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "zone_pricing_override_resolution_pricing_plan_version_id_fkey"
      columns: ["pricing_plan_version_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "zone_pricing_override_resolution_resolved_by_fkey"
      columns: ["resolved_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "zone_pricing_override_resolution_zone_pricing_override_id_fkey"
      columns: ["zone_pricing_override_id"]
isOneToOne: false
      referencedRelation: "zone_pricing_overrides"
      referencedColumns: ["id"]
    }
                  ]
                },"zone_pricing_overrides": {
                  Row: {
                    "created_at": string,"effective_from": string,"effective_to": string | null,"id": string,"multiplier": number,"pricing_plan_id": string | null,"reason": string | null,"service_zone_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"effective_from": string,"effective_to"?: string | null,"id"?: string,"multiplier": number,"pricing_plan_id"?: string | null,"reason"?: string | null,"service_zone_id": string
                  }
                  Update: {
                    "created_at"?: string,"effective_from"?: string,"effective_to"?: string | null,"id"?: string,"multiplier"?: number,"pricing_plan_id"?: string | null,"reason"?: string | null,"service_zone_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "zone_pricing_overrides_pricing_plan_id_fkey"
      columns: ["pricing_plan_id"]
isOneToOne: false
      referencedRelation: "pricing_plan_versions"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "zone_pricing_overrides_service_zone_id_fkey"
      columns: ["service_zone_id"]
isOneToOne: false
      referencedRelation: "service_zones"
      referencedColumns: ["id"]
    }
                  ]
                }
          }
          Views: {
            "active_demand_zones": {
                  Row: {
                    "avg_wait_seconds": number | null,"current_demand_score": number | null,"current_supply": number,"service_zone_id": string,"zone_name": string
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "demand_snapshots_service_zone_id_fkey"
      columns: ["service_zone_id"]
isOneToOne: false
      referencedRelation: "service_zones"
      referencedColumns: ["id"]
    }
                  ]
                },"active_fleet_roster": {
                  Row: {
                    "active_drivers": (string)[] | null,"active_jobs_count": number | null,"active_vehicles": (string)[] | null,"fleet_id": string,"fleet_name": string
                  }
                  ComputedFields: never
                  Insert: {
                           "active_drivers"?: never,"active_jobs_count"?: never,"active_vehicles"?: never,"fleet_id"?: string | null,"fleet_name"?: string | null
                         }
                        Update: {
                           "active_drivers"?: never,"active_jobs_count"?: never,"active_vehicles"?: never,"fleet_id"?: string | null,"fleet_name"?: string | null
                         }
                        Relationships: [
                    
                  ]
                },"active_jobs_by_driver": {
                  Row: {
                    "distance_to_pickup_km": number | null,"driver_id": string | null,"job_id": string,"pickup_address": string | null,"scheduled_at": string | null,"status": Database["public"]['Enums']["job_status"]
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "jobs_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_dashboard_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "jobs_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "driver_verification_summary"
      referencedColumns: ["driver_id"]
    },{
      foreignKeyName: "jobs_driver_id_fkey"
      columns: ["driver_id"]
isOneToOne: false
      referencedRelation: "drivers"
      referencedColumns: ["id"]
    }
                  ]
                },"audit_log_view": {
                  Row: {
                    "action": Database["public"]['Enums']["audit_action"] | null,"actor_id": string | null,"actor_role": Database["public"]['Enums']["user_role"] | null,"created_at": string | null,"entity_id": string | null,"entity_type": string | null,"id": number | null,"ip_address": unknown,"new_value": Json | null,"old_value": Json | null,"session_id": string | null,"user_agent": string | null
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"chat_unread_summary": {
                  Row: {
                    "job_id": string,"last_message_at": string | null,"profile_id": string,"thread_id": string,"unread_count": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "chat_read_receipts_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "chat_threads_job_id_fkey"
      columns: ["job_id"]
isOneToOne: true
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "chat_threads_job_id_fkey"
      columns: ["job_id"]
isOneToOne: true
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "chat_threads_job_id_fkey"
      columns: ["job_id"]
isOneToOne: true
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "chat_threads_job_id_fkey"
      columns: ["job_id"]
isOneToOne: true
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"dispute_summary": {
                  Row: {
                    "age_hours": number | null,"assigned_to_name": string | null,"dispute_id": string,"dispute_type": string,"job_id": string,"priority": string,"raised_by_name": string | null,"sla_due_at": string | null,"status": string
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "disputes_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "disputes_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "disputes_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "disputes_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"driver_dashboard_summary": {
                  Row: {
                    "acceptance_rate_30d": number | null,"active_offer_count": number | null,"driver_id": string,"rating_30d": number | null,"today_earnings": number | null,"today_trips": number | null,"week_earnings": number | null,"week_trips": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "drivers_id_fkey"
      columns: ["driver_id"]
isOneToOne: true
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"driver_earnings_summary": {
                  Row: {
                    "commissions_deducted": number | null,"driver_id": string | null,"gross_earnings": number | null,"net_earnings": number | null,"payout_status": string | null,"period": string | null,"period_start": string | null,"withholding_tax": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"driver_public_profile": {
                  Row: {
                    "avatar_url": string | null,"current_vehicle_id": string | null,"display_name": string | null,"full_name": string | null,"home_city_id": string | null,"id": string | null,"rating": number | null,"total_trips": number | null,"verification_status": Database["public"]['Enums']["driver_verification_status"] | null
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"driver_verification_summary": {
                  Row: {
                    "driver_id": string,"is_fully_verified": boolean | null,"next_expiry_date": string | null,"total_documents_required": number | null,"total_documents_submitted": number | null,"total_expired": number | null,"total_verified": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "drivers_id_fkey"
      columns: ["driver_id"]
isOneToOne: true
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"incident_summary": {
                  Row: {
                    "age_hours": number | null,"assigned_to_name": string | null,"id": string,"incident_type": string,"job_id": string | null,"reported_by_name": string | null,"severity": string,"status": string
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "incidents_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "incidents_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "incidents_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "incidents_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"invoice_summary": {
                  Row: {
                    "business_name": string | null,"days_overdue": number | null,"due_at": string | null,"invoice_id": string,"invoice_number": string,"issued_at": string | null,"status": string,"total": number
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"job_payment_summary": {
                  Row: {
                    "commission_amount": number | null,"currency_code": string | null,"customer_name": string | null,"driver_net_earning": number | null,"job_id": string,"payment_status": Database["public"]['Enums']["payment_status"],"total_paid": number | null,"total_refunded": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"job_summary": {
                  Row: {
                    "currency_code": string | null,"customer_name": string | null,"destination_address": string | null,"driver_name": string | null,"final_amount": number | null,"job_id": string,"pickup_address": string | null,"quote_id": string,"rating_count": number | null,"scheduled_at": string | null,"status": Database["public"]['Enums']["job_status"]
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "jobs_quote_id_fkey"
      columns: ["quote_id"]
isOneToOne: false
      referencedRelation: "quote_summary"
      referencedColumns: ["quote_id"]
    },{
      foreignKeyName: "jobs_quote_id_fkey"
      columns: ["quote_id"]
isOneToOne: false
      referencedRelation: "quotes"
      referencedColumns: ["id"]
    }
                  ]
                },"matching_performance": {
                  Row: {
                    "avg_attempts_to_match": number | null,"avg_seconds_to_match": number | null,"date": string | null,"success_rate": number | null,"total_attempts": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"notification_summary": {
                  Row: {
                    "last_notification_at": string | null,"notification_count_today": number | null,"notification_count_week": number | null,"profile_id": string,"unread_count": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "notification_log_profile_id_fkey"
      columns: ["profile_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"operational_dashboard": {
                  Row: {
                    "active_incidents": number | null,"completed_today": number | null,"jobs_today": number | null,"metric_date": string | null,"open_tickets": number | null,"unread_chats": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"payment_reconciliation": {
                  Row: {
                    "amount": number,"is_reconciled": boolean | null,"job_id": string,"last_webhook_at": string | null,"payment_id": string,"provider": string,"provider_status": string,"webhook_count": number | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "payments_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "active_jobs_by_driver"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "payments_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_payment_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "payments_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "job_summary"
      referencedColumns: ["job_id"]
    },{
      foreignKeyName: "payments_job_id_fkey"
      columns: ["job_id"]
isOneToOne: false
      referencedRelation: "jobs"
      referencedColumns: ["id"]
    }
                  ]
                },"payout_batch_summary": {
                  Row: {
                    "batch_id": string,"country": string,"currency_code": string,"driver_count": number,"period_end": string,"period_start": string,"status": string,"total_amount": number
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "payout_batches_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    }
                  ]
                },"pricing_plan_summary": {
                  Row: {
                    "base_fare": number,"city_name": string,"currency_code": string,"current_effective_from": string,"current_version_number": number,"is_regulated": boolean | null,"minimum_charge": number,"per_km_rate": number,"per_min_rate": number,"plan_code": string,"plan_id": string,"plan_name": string,"vehicle_type_name": string,"zone_name": string | null
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "pricing_plan_base_rates_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    }
                  ]
                },"promo_code_active": {
                  Row: {
                    "code": string,"currency_code": string | null,"description": string | null,"discount_type": string,"discount_value": number,"id": string,"max_discount_amount": number | null,"min_purchase_amount": number,"name": string,"new_users_only": boolean,"per_user_redemption_limit": number,"redemption_count": number | null,"remaining_capacity": number | null,"total_redemption_limit": number | null,"valid_from": string,"valid_to": string
                  }
                  ComputedFields: never
                  Insert: {
                           "code"?: string | null,"currency_code"?: string | null,"description"?: string | null,"discount_type"?: string | null,"discount_value"?: number | null,"id"?: string | null,"max_discount_amount"?: number | null,"min_purchase_amount"?: number | null,"name"?: string | null,"new_users_only"?: boolean | null,"per_user_redemption_limit"?: number | null,"redemption_count"?: never,"remaining_capacity"?: never,"total_redemption_limit"?: number | null,"valid_from"?: string | null,"valid_to"?: string | null
                         }
                        Update: {
                           "code"?: string | null,"currency_code"?: string | null,"description"?: string | null,"discount_type"?: string | null,"discount_value"?: number | null,"id"?: string | null,"max_discount_amount"?: number | null,"min_purchase_amount"?: number | null,"name"?: string | null,"new_users_only"?: boolean | null,"per_user_redemption_limit"?: number | null,"redemption_count"?: never,"remaining_capacity"?: never,"total_redemption_limit"?: number | null,"valid_from"?: string | null,"valid_to"?: string | null
                         }
                        Relationships: [
                    {
      foreignKeyName: "promo_codes_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    }
                  ]
                },"quote_summary": {
                  Row: {
                    "created_at": string,"currency_code": string,"customer_name": string | null,"expires_at": string,"quote_id": string,"quote_request_id": string,"total": number,"vehicle_type_name": string
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "quotes_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    },{
      foreignKeyName: "quotes_quote_request_id_fkey"
      columns: ["quote_request_id"]
isOneToOne: false
      referencedRelation: "quote_requests"
      referencedColumns: ["id"]
    }
                  ]
                },"regulated_tariff_bands_summary": {
                  Row: {
                    "band_type": string,"max_fare": number,"max_value": number | null,"min_fare": number,"min_value": number,"regulatory_body": string,"tariff_id": string,"tariff_name": string,"value_unit": string
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"support_ticket_summary": {
                  Row: {
                    "age_hours": number | null,"assigned_to_name": string | null,"opened_by_name": string | null,"priority": string,"sla_breached": boolean | null,"status": string,"subject": string,"ticket_number": string
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"vehicle_public_view": {
                  Row: {
                    "capacity_kg": number,"home_city_name": string | null,"id": string,"photo_urls": (string)[],"vehicle_type_name": string,"verification_status_bool": boolean | null
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"vehicle_verification_summary": {
                  Row: {
                    "is_fully_verified": boolean | null,"next_expiry_date": string | null,"total_documents_required": number | null,"total_documents_submitted": number | null,"total_expired": number | null,"total_verified": number | null,"vehicle_id": string
                  }
                  ComputedFields: never
                  Relationships: [
                    
                  ]
                },"wallet_balance_current": {
                  Row: {
                    "cached_balance": number,"currency_code": string,"last_transaction_at": string | null,"profile_name": string | null,"wallet_id": string
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "wallets_currency_code_fkey"
      columns: ["currency_code"]
isOneToOne: false
      referencedRelation: "currencies"
      referencedColumns: ["code"]
    }
                  ]
                }
          }
          Functions: {
            "accept_job_offer":
{ Args: { "p_offer_id": string }; Returns: undefined
                           },
"active_pricing_plan_for":
{ Args: { "p_at_time"?: string,"p_city_id": string,"p_vehicle_type_id": string,"p_zone_id": string }; Returns: string
                           },
"active_pricing_plan_version":
{ Args: { "p_at_time"?: string,"p_pricing_plan_id": string }; Returns: string
                           },
"apply_retention_policies":
{ Args: Record<PropertyKey, never>; Returns: {
              "rows_deleted": number,"table_name": string
            }[]
                           },
"apply_withholding_tax":
{ Args: { "p_job_id": string }; Returns: number
                           },
"archive_stale_chat_threads":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"business_has_members":
{ Args: { "p_business_account_id": string }; Returns: boolean
                           },
"calculate_and_record_commission":
{ Args: { "p_job_id": string }; Returns: string
                           },
"can_carry_cargo":
{ Args: { "p_cargo_type_id": string,"p_vehicle_id": string }; Returns: boolean
                           },
"capture_demand_snapshot":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"compute_customer_metrics":
{ Args: { "p_target_date"?: string }; Returns: number
                           },
"compute_daily_metrics":
{ Args: { "p_target_date"?: string }; Returns: number
                           },
"compute_driver_metrics":
{ Args: { "p_target_date"?: string }; Returns: number
                           },
"compute_zone_metrics":
{ Args: { "p_target_date"?: string }; Returns: number
                           },
"create_payout_batch":
{ Args: { "p_country_id": string,"p_period_end": string,"p_period_start": string }; Returns: string
                           },
"current_country_id":
{ Args: Record<PropertyKey, never>; Returns: string
                           },
"current_profile_id":
{ Args: Record<PropertyKey, never>; Returns: string
                           },
"current_user_role":
{ Args: Record<PropertyKey, never>; Returns: Database["public"]['Enums']["user_role"]
                           },
"custom_access_token_hook":
{ Args: { "event": Json }; Returns: Json
                           },
"deactivate_user":
{ Args: { "profile_id": string,"reason": string }; Returns: boolean
                           },
"decline_job_offer":
{ Args: { "p_offer_id": string,"p_reason"?: string }; Returns: undefined
                           },
"dispatch_rule_for":
{ Args: { "p_city_id": string,"p_vehicle_type_id": string }; Returns: {
              "city_id": string | null,
"country_id": string | null,
"created_at": string,
"id": string,
"is_active": boolean,
"max_concurrent_offers": number,
"max_search_radius_km": number,
"min_driver_rating": number | null,
"minimum_acceptance_rate": number | null,
"offer_timeout_seconds": number,
"reassign_after_seconds": number,
"updated_at": string,
"vehicle_type_id": string | null
            }
                          SetofOptions: {
        from: "*"
        to: "dispatch_rules"
        isOneToOne: true
        isSetofReturn: false
      } },
"draft_pricing_plan_version":
{ Args: { "p_pricing_plan_id": string }; Returns: string
                           },
"driver_current_vehicle":
{ Args: { "p_driver_id": string }; Returns: string
                           },
"driver_requires_verification":
{ Args: { "p_driver_id": string }; Returns: boolean
                           },
"execute_payout":
{ Args: { "p_payout_id": string }; Returns: string
                           },
"expire_stale_offers":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"find_nearby_drivers":
{ Args: { "p_limit"?: number,"p_pickup_location": unknown,"p_radius_km"?: number,"p_vehicle_type_id": string }; Returns: {
              "acceptance_rate": number,"distance_km": number,"driver_id": string,"eta_minutes": number,"rating": number
            }[]
                           },
"generate_invoice":
{ Args: { "p_business_account_id": string,"p_period_end": string,"p_period_start": string }; Returns: string
                           },
"get_audit_log":
{ Args: { "p_entity_id"?: string,"p_entity_type"?: string,"p_limit"?: number }; Returns: {
              "action": Database["public"]['Enums']["audit_action"],"actor_id": string,"actor_role": Database["public"]['Enums']["user_role"],"created_at": string,"entity_id": string,"entity_type": string,"id": number,"ip_address": unknown,"new_value": Json,"old_value": Json,"session_id": string,"user_agent": string
            }[]
                           },
"get_public_driver_profile":
{ Args: { "p_driver_id"?: string }; Returns: {
              "avatar_url": string,"current_vehicle_id": string,"display_name": string,"full_name": string,"home_city_id": string,"id": string,"rating": number,"total_trips": number,"verification_status": Database["public"]['Enums']["driver_verification_status"]
            }[]
                           },
"has_admin_role":
{ Args: { "role_name": string }; Returns: boolean
                           },
"has_permission":
{ Args: { "permission_key": string }; Returns: boolean
                           } |
{ Args: { "city_id": string,"permission_key": string }; Returns: boolean
                           },
"is_business_admin":
{ Args: { "p_business_account_id": string }; Returns: boolean
                           },
"is_business_member":
{ Args: { "p_business_account_id": string }; Returns: boolean
                           },
"is_business_owner":
{ Args: { "p_business_account_id": string }; Returns: boolean
                           },
"is_fleet_member":
{ Args: { "p_fleet_id": string }; Returns: boolean
                           },
"is_fleet_owner":
{ Args: { "p_fleet_id": string }; Returns: boolean
                           },
"is_privileged_writer":
{ Args: Record<PropertyKey, never>; Returns: boolean
                           },
"is_vehicle_owner":
{ Args: { "p_vehicle_id": string }; Returns: boolean
                           },
"job_advance_status":
{ Args: { "p_job_id": string,"p_new_status": Database["public"]['Enums']["job_status"],"p_reason"?: string }; Returns: undefined
                           },
"job_assign_driver":
{ Args: { "p_driver_id": string,"p_job_id": string,"p_vehicle_id"?: string }; Returns: undefined
                           },
"job_cancel":
{ Args: { "p_cancelled_by": string,"p_job_id": string,"p_reason": string }; Returns: undefined
                           },
"job_pay":
{ Args: { "p_idempotency_key"?: string,"p_job_id": string,"p_payment_method_id": string,"p_provider_id": string,"p_provider_reference": string }; Returns: string
                           },
"job_refund":
{ Args: { "p_job_id": string,"p_reason": string,"p_refund_amount": number,"p_refund_type": string }; Returns: string
                           },
"log_data_access":
{ Args: { "p_access_type": string,"p_accessor_id": string,"p_authorized"?: boolean,"p_field": string,"p_purpose": string,"p_table": string,"p_target_id": string,"p_target_profile_id": string }; Returns: number
                           },
"log_pii_select":
{ Args: { "p_target_field": string,"p_target_profile_id": string,"p_target_table": string }; Returns: boolean
                           },
"offer_job_to_driver":
{ Args: { "p_driver_id": string,"p_job_id": string,"p_offer_timeout_seconds"?: number }; Returns: string
                           },
"payment_refund":
{ Args: { "p_payment_id": string,"p_reason": string,"p_refund_amount": number,"p_refund_type": string }; Returns: string
                           },
"pending_verifications_for_admin":
{ Args: { "p_admin_profile_id": string }; Returns: {
              "assigned_at": string | null,
"assigned_to": string | null,
"business_account_id": string | null,
"created_at": string,
"decided_at": string | null,
"decision_notes": string | null,
"driver_id": string | null,
"id": string,
"priority": string,
"request_type": string,
"requested_by": string,
"reviewed_at": string | null,
"sla_due_at": string | null,
"status": string,
"submitted_at": string,
"updated_at": string,
"vehicle_id": string | null
            }[]
                          SetofOptions: {
        from: "*"
        to: "verification_requests"
        isOneToOne: false
        isSetofReturn: true
      } },
"promo_code_valid":
{ Args: { "p_at_time"?: string,"p_profile_id": string,"p_promo_code_id": string }; Returns: boolean
                           },
"publish_pricing_plan_version":
{ Args: { "p_version_id": string }; Returns: string
                           },
"quote_calculate_and_persist":
{ Args: { "p_cargo_type_id": string,"p_cargo_volume_m3"?: number,"p_cargo_weight_kg"?: number,"p_customer_id": string,"p_destination_address": string,"p_destination_location": unknown,"p_distance_km"?: number,"p_duration_min"?: number,"p_equipment_ids"?: (string)[],"p_pickup_address": string,"p_pickup_location": unknown,"p_promo_code_id"?: string,"p_scheduled_at"?: string,"p_stop_count"?: number,"p_vehicle_type_id": string,"p_waiting_minutes"?: number }; Returns: string
                           },
"quote_cleanup":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"quote_get_breakdown":
{ Args: { "p_quote_id": string }; Returns: Json
                           },
"quote_preview":
{ Args: { "p_at_time"?: string,"p_cargo_type_id": string,"p_distance_km": number,"p_duration_min": number,"p_equipment_ids": (string)[],"p_pricing_plan_version_id": string,"p_volume_m3": number,"p_weight_kg": number,"p_zone_id": string }; Returns: Json
                           },
"recompute_all_driver_acceptance_stats":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"recompute_driver_rating":
{ Args: { "p_driver_id": string }; Returns: undefined
                           },
"record_consent":
{ Args: { "consent_type": string,"consent_version": string,"granted": boolean,"profile_id": string }; Returns: string
                           },
"regulated_max_fare":
{ Args: { "p_distance_km": number,"p_regulated_tariff_id": string,"p_weight_kg": number }; Returns: number
                           },
"resolve_commission_rule":
{ Args: { "p_job_id": string }; Returns: string
                           },
"resolve_tax_rate":
{ Args: { "p_applies_to": string,"p_at_time"?: string,"p_country_id": string,"p_tax_type": string }; Returns: number
                           },
"send_notification":
{ Args: { "p_channel": string,"p_profile_id": string,"p_reference_id"?: string,"p_reference_type"?: string,"p_template_code": string,"p_variables": Json }; Returns: string
                           },
"vehicle_current_driver":
{ Args: { "p_vehicle_id": string }; Returns: string
                           },
"vehicle_requires_verification":
{ Args: { "p_vehicle_id": string }; Returns: boolean
                           },
"verify_all_wallet_balances":
{ Args: Record<PropertyKey, never>; Returns: {
              "cached": number,"computed": number,"matches": boolean,"wallet_id": string
            }[]
                           },
"wallet_balance_verify":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"wallet_credit":
{ Args: { "p_amount": number,"p_currency_code": string,"p_description"?: string,"p_profile_id": string,"p_reference_id"?: string,"p_reference_type"?: string,"p_transaction_type": string }; Returns: string
                           },
"wallet_debit":
{ Args: { "p_allow_negative"?: boolean,"p_amount": number,"p_currency_code": string,"p_description"?: string,"p_profile_id": string,"p_reference_id"?: string,"p_reference_type"?: string,"p_transaction_type": string }; Returns: string
                           },
"zone_pricing_override_plan_version":
{ Args: { "p_zone_pricing_override_id": string }; Returns: string
                           }
          }
          Enums: {
            "audit_action": "insert"|"update"|"delete"|"login"|"logout"|"verification_approved"|"verification_rejected"|"payout_changed"|"pricing_changed"|"admin_override"|"consent_granted"|"consent_revoked"|"user_suspended"|"user_reactivated","driver_risk_tier": "standard"|"enhanced"|"restricted","driver_verification_status": "pending"|"verified"|"rejected"|"re_verification_due"|"suspended","evidence_type": "pickup_photo"|"delivery_photo"|"signature"|"otp"|"document"|"item_photo"|"cargo_manifest","job_status": "requested"|"quoted"|"matched"|"accepted"|"heading_to_pickup"|"arrived"|"loading"|"in_transit"|"delivered"|"completed"|"cancelled"|"disputed","payment_method": "mpesa"|"tigopesa"|"airtelmoney"|"halopesa"|"card"|"cash"|"wallet","payment_status": "pending"|"paid"|"refunded"|"failed"|"partially_refunded","trip_alert_type": "route_deviation"|"prolonged_stop"|"sos"|"unusual_activity","user_role": "customer"|"driver"|"business"|"admin"|"fleet_owner"
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "public": {
          Enums: {
            "audit_action": ["insert", "update", "delete", "login", "logout", "verification_approved", "verification_rejected", "payout_changed", "pricing_changed", "admin_override", "consent_granted", "consent_revoked", "user_suspended", "user_reactivated"],"driver_risk_tier": ["standard", "enhanced", "restricted"],"driver_verification_status": ["pending", "verified", "rejected", "re_verification_due", "suspended"],"evidence_type": ["pickup_photo", "delivery_photo", "signature", "otp", "document", "item_photo", "cargo_manifest"],"job_status": ["requested", "quoted", "matched", "accepted", "heading_to_pickup", "arrived", "loading", "in_transit", "delivered", "completed", "cancelled", "disputed"],"payment_method": ["mpesa", "tigopesa", "airtelmoney", "halopesa", "card", "cash", "wallet"],"payment_status": ["pending", "paid", "refunded", "failed", "partially_refunded"],"trip_alert_type": ["route_deviation", "prolonged_stop", "sos", "unusual_activity"],"user_role": ["customer", "driver", "business", "admin", "fleet_owner"]
          }
        }
} as const
