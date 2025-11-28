package com.koosco.authservice.application.client

import com.koosco.authservice.infra.client.dto.UserInfoResponse

interface UserServiceClient {
    fun getUserInfo(userId: Long): UserInfoResponse
}
