package com.koosco.authservice.application.dto

import com.koosco.authservice.domain.vo.AuthProvider

data class CreateUserDto(val userId: Long, val email: String, val password: String, val provider: AuthProvider? = null)

data class LoginDto(val email: String, val password: String)
