package com.koosco.authservice.infra.client

import com.koosco.authservice.infra.client.dto.UserInfoResponse
import org.springframework.cloud.openfeign.FeignClient
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable

@FeignClient(name = "user-service", url = "\${user-service.url:http://localhost:8081}")
interface UserClient {

    @GetMapping("/api/user/{userId}")
    fun getUserInfo(@PathVariable userId: Long): UserInfoResponse
}
