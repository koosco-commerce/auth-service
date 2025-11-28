package com.koosco.authservice.infra.client

import com.koosco.authservice.application.client.UserServiceClient
import com.koosco.authservice.infra.client.dto.UserInfoResponse
import org.springframework.stereotype.Component

@Component
class UserClientAdapter(private val userClient: UserClient) : UserServiceClient {

    override fun getUserInfo(userId: Long): UserInfoResponse = userClient.getUserInfo(userId)
}
