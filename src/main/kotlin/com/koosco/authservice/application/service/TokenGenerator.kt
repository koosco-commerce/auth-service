package com.koosco.authservice.application.service

import com.koosco.authservice.application.dto.AuthTokenDto

interface TokenGenerator {
    fun generateTokens(userId: Long, email: String): AuthTokenDto

    fun validateRefreshToken(token: String): Boolean
}
