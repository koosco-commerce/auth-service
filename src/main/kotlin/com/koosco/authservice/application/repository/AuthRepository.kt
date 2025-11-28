package com.koosco.authservice.application.repository

import com.koosco.authservice.domain.entity.UserAuth

interface AuthRepository {

    fun save(userAuth: UserAuth): UserAuth

    fun findByEmail(email: String): UserAuth?
}
