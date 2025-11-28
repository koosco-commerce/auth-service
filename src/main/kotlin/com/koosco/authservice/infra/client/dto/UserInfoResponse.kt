package com.koosco.authservice.infra.client.dto

data class UserInfoResponse(
    val id: Long,
    val email: String,
    val name: String,
    val phone: String?,
    val roles: List<String>,
)
