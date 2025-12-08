package com.koosco.authservice.api.controller

import com.koosco.authservice.api.dto.request.CreateUserRequest
import com.koosco.authservice.api.dto.request.LoginRequest
import com.koosco.authservice.api.dto.request.toDto
import com.koosco.authservice.application.usecase.LoginUseCase
import com.koosco.authservice.application.usecase.RegisterUseCase
import com.koosco.common.core.response.ApiResponse
import io.swagger.v3.oas.annotations.Hidden
import io.swagger.v3.oas.annotations.Operation
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.ResponseCookie
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/auth")
class AuthController(private val registerUseCase: RegisterUseCase, private val loginUseCase: LoginUseCase) {

    @Hidden
    @Operation(
        summary = "사용자 인증 정보 등록 (user-service 호출)",
        description = "새로운 사용자의 인증 정보를 등록합니다.",
    )
    @PostMapping
    fun registerUser(@RequestBody request: CreateUserRequest): ApiResponse<Any> {
        registerUseCase.register(request.toDto())

        return ApiResponse.success()
    }

    @Operation(
        summary = "로컬 사용자 로그인",
        description = "로컬 사용자로 로그인합니다.",
    )
    @PostMapping("/login")
    fun login(@RequestBody request: LoginRequest, response: HttpServletResponse): ApiResponse<Any> {
        val dto = loginUseCase.login(request.toDto())

        response.addHeader("Authorization", dto.accessToken)

        val refreshTokenCookie = ResponseCookie.from("refreshToken", dto.refreshToken)
            .httpOnly(true)
            .secure(true)
            .path("/")
            .maxAge(dto.refreshTokenExpiresIn)
            .sameSite("Strict")
            .build()
        response.addHeader("Set-Cookie", refreshTokenCookie.toString())

        return ApiResponse.success()
    }
}
