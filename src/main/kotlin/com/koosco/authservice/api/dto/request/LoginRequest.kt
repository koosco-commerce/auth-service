package com.koosco.authservice.api.dto.request

import com.koosco.authservice.application.dto.LoginDto

data class LoginRequest(val email: String, val password: String)

fun LoginRequest.toDto(): LoginDto = LoginDto(
    email = this.email,
    password = this.password,
)
