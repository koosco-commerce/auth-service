package com.koosco.authservice.application.usecase

import com.koosco.authservice.application.client.UserServiceClient
import com.koosco.authservice.application.dto.AuthTokenDto
import com.koosco.authservice.application.dto.LoginDto
import com.koosco.authservice.application.repository.AuthRepository
import com.koosco.authservice.application.service.TokenGenerator
import com.koosco.authservice.common.AuthErrorCode
import com.koosco.common.core.annotation.UseCase
import com.koosco.common.core.exception.NotFoundException
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.transaction.annotation.Transactional

@UseCase
class LoginUseCase(
    private val authRepository: AuthRepository,
    private val passwordEncoder: PasswordEncoder,
    private val tokenGenerator: TokenGenerator,
    private val userServiceClient: UserServiceClient,
) {
    @Transactional
    fun login(toDto: LoginDto): AuthTokenDto {
        val userAuth = authRepository.findByEmail(toDto.email)
            ?: throw NotFoundException(AuthErrorCode.PROVIDER_USER_NOT_FOUND)

        val encodedPassword = userAuth.password

        passwordEncoder.matches(toDto.password, encodedPassword.value)
            .takeIf { it }
            ?: throw NotFoundException(AuthErrorCode.PROVIDER_USER_NOT_FOUND)

        val userInfo = userServiceClient.getUserInfo(userAuth.userId)

        val tokens = tokenGenerator.generateTokens(userAuth.userId, userAuth.email.value, userInfo.roles)

        userAuth.storeRefreshToken(tokens.refreshToken)

        return tokens
    }
}
