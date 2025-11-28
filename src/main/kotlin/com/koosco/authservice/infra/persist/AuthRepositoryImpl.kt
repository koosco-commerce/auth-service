package com.koosco.authservice.infra.persist

import com.koosco.authservice.application.repository.AuthRepository
import com.koosco.authservice.domain.entity.UserAuth
import org.springframework.stereotype.Repository

@Repository
class AuthRepositoryImpl(private val jpaAuthRepository: JpaAuthRepository) : AuthRepository {

    override fun save(userAuth: UserAuth): UserAuth = jpaAuthRepository.save(userAuth)

    override fun findByEmail(email: String): UserAuth? = jpaAuthRepository.findByEmail(email)
}
