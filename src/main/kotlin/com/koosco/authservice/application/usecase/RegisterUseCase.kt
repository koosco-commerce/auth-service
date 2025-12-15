package com.koosco.authservice.application.usecase

import com.koosco.authservice.application.dto.CreateUserCommand
import com.koosco.authservice.application.repository.AuthRepository
import com.koosco.authservice.domain.entity.UserAuth
import com.koosco.authservice.domain.vo.Email
import com.koosco.authservice.domain.vo.EncryptedPassword
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
class RegisterUseCase(private val authRepository: AuthRepository, private val passwordEncoder: PasswordEncoder) {

    @Transactional
    fun execute(command: CreateUserCommand) {
        val email = Email.of(command.email)
        val encryptedPassword = EncryptedPassword.of(passwordEncoder.encode(command.password))

        val userAuth = UserAuth.createUser(
            userId = command.userId,
            email = email,
            password = encryptedPassword,
            provider = command.provider,
        )

        authRepository.save(userAuth)
    }
}
