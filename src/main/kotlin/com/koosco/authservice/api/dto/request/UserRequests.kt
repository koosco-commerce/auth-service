package com.koosco.authservice.api.dto.request

import com.koosco.authservice.application.dto.CreateUserDto
import com.koosco.authservice.domain.vo.AuthProvider

data class CreateUserRequest(
    val userId: Long,
    val email: String,
    val password: String,
    val provider: AuthProvider? = null,
)

fun CreateUserRequest.toDto(): CreateUserDto = CreateUserDto(
    userId = this.userId,
    email = this.email,
    password = this.password,
    provider = this.provider,
)

data class DeleteUserRequest(val userId: Long)
