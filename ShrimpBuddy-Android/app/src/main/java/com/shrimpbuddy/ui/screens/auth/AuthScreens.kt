package com.shrimpbuddy.ui.screens.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shrimpbuddy.models.LoginRequest
import com.shrimpbuddy.models.RegisterRequest
import com.shrimpbuddy.network.RetrofitClient
import com.shrimpbuddy.ui.theme.*
import kotlinx.coroutines.launch

// ─── Shared Components ────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SBTextField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String = "",
    isPassword: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text(
            label.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
            color = SBOnSurfaceVariant,
            modifier = Modifier.padding(bottom = 5.dp)
        )
        OutlinedTextField(
            value = value, onValueChange = onValueChange,
            placeholder = { Text(placeholder, fontSize = 14.sp, color = SBOnSurfaceDim) },
            visualTransformation = if (isPassword) PasswordVisualTransformation()
                                   else androidx.compose.ui.text.input.VisualTransformation.None,
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            shape = RoundedCornerShape(10.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor   = SBPrimary,
                unfocusedBorderColor = SBOutline,
                focusedContainerColor   = SBSurfaceElevated,
                unfocusedContainerColor = SBSurfaceElevated,
                focusedTextColor    = SBOnSurface,
                unfocusedTextColor  = SBOnSurface,
                cursorColor         = SBPrimary
            ),
            modifier = Modifier.fillMaxWidth().height(52.dp),
            singleLine = true
        )
    }
}

@Composable
fun SBPrimaryButton(text: String, isLoading: Boolean = false, onClick: () -> Unit) {
    Button(
        onClick = onClick, enabled = !isLoading,
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = SBPrimary,
            disabledContainerColor = SBPrimaryDim
        ),
        modifier = Modifier.fillMaxWidth().height(52.dp)
    ) {
        if (isLoading)
            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
        else
            Text(text, fontWeight = FontWeight.Bold, fontSize = 15.sp, color = Color.White)
    }
}

@Composable
fun SBSecondaryButton(text: String, onClick: () -> Unit) {
    OutlinedButton(
        onClick = onClick,
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.outlinedButtonColors(
            contentColor = SBPrimaryLight,
            containerColor = SBPrimaryDim
        ),
        border = androidx.compose.foundation.BorderStroke(1.dp, SBOutlineVariant),
        modifier = Modifier.fillMaxWidth().height(52.dp)
    ) { Text(text, fontWeight = FontWeight.SemiBold, fontSize = 15.sp) }
}

@Composable
fun ErrorBanner(message: String) {
    Row(
        modifier = Modifier.fillMaxWidth()
            .background(SBErrorBg, RoundedCornerShape(10.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("⚠️ ", fontSize = 13.sp)
        Text(message, color = SBError, fontSize = 13.sp)
    }
}

// ─── Login Screen ─────────────────────────────────────────────────────────────

@Composable
fun LoginScreen(
    onLoginSuccess: () -> Unit,
    onNavigateToRegister: () -> Unit,
    onNavigateToForgot: () -> Unit
) {
    val scope = rememberCoroutineScope()
    var email    by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var error    by remember { mutableStateOf<String?>(null) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(Color(0xFF020912), Color(0xFF060E1C), Color(0xFF091628))
                )
            )
    ) {
        // Glow orb
        Box(
            modifier = Modifier
                .size(300.dp)
                .align(Alignment.TopCenter)
                .offset(y = (-80).dp)
                .blur(60.dp)
                .background(Color(0xFF4487E0).copy(alpha = 0.07f), CircleShape)
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 26.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(72.dp))

            // Logo
            Box(
                modifier = Modifier
                    .size(84.dp)
                    .background(Color(0xFF1A3560), CircleShape),
                contentAlignment = Alignment.Center
            ) { Text("🦐", fontSize = 38.sp) }

            Spacer(Modifier.height(18.dp))

            Text("Shrimp Buddy",
                fontSize = 28.sp, fontWeight = FontWeight.Bold,
                color = SBOnSurface)

            Text("SMART AQUACULTURE MANAGEMENT",
                fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                color = SBOnSurfaceVariant, letterSpacing = 1.4.sp,
                modifier = Modifier.padding(top = 4.dp))

            Spacer(Modifier.height(44.dp))

            // Form
            SBTextField("Farm Email", email, { email = it }, "you@farm.com",
                keyboardType = KeyboardType.Email)
            Spacer(Modifier.height(14.dp))
            SBTextField("Password", password, { password = it }, "Enter password", isPassword = true)

            Row(
                Modifier.fillMaxWidth().padding(top = 6.dp),
                horizontalArrangement = Arrangement.End
            ) {
                TextButton(onClick = onNavigateToForgot) {
                    Text("Forgot Password?", fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold, color = SBPrimaryLight)
                }
            }

            error?.let {
                Spacer(Modifier.height(4.dp))
                ErrorBanner(it)
            }
            Spacer(Modifier.height(18.dp))

            SBPrimaryButton("Sign In", isLoading) {
                if (email.isBlank() || password.isBlank()) {
                    error = "Please enter your email and password."
                    return@SBPrimaryButton
                }
                scope.launch {
                    isLoading = true; error = null
                    try {
                        val response = RetrofitClient.api.login(LoginRequest(email, password))
                        if (response.isSuccessful && response.body()?.success == true) {
                            onLoginSuccess()
                        } else {
                            error = response.body()?.error ?: "Login failed. Please try again."
                        }
                    } catch (e: Exception) { error = e.message }
                    isLoading = false
                }
            }

            Spacer(Modifier.height(12.dp))

            Row(
                Modifier.fillMaxWidth().padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Divider(Modifier.weight(1f), color = SBOutline)
                Text("  OR  ", fontSize = 11.sp, color = SBOnSurfaceDim)
                Divider(Modifier.weight(1f), color = SBOutline)
            }

            Spacer(Modifier.height(12.dp))
            SBSecondaryButton("Create Farm Workspace", onNavigateToRegister)
            Spacer(Modifier.height(32.dp))

            Text(
                "By signing in, you agree to our Terms & Privacy Policies.",
                fontSize = 11.sp, color = SBOnSurfaceDim, textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            Spacer(Modifier.height(40.dp))
        }
    }
}

// ─── Register Screen ──────────────────────────────────────────────────────────

@Composable
fun RegisterScreen(onSuccess: () -> Unit, onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var farmName by remember { mutableStateOf("") }
    var email    by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var error    by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(SBBg)
            .verticalScroll(rememberScrollState())
            .padding(24.dp)
    ) {
        TextButton(onClick = onBack) {
            Text("← Back to Sign In", fontWeight = FontWeight.SemiBold, color = SBPrimaryLight)
        }
        Spacer(Modifier.height(8.dp))
        Text("Get Started", fontSize = 26.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)
        Text("Set up your smart farm workspace", fontSize = 13.sp, color = SBOnSurfaceVariant)
        Spacer(Modifier.height(28.dp))

        SBTextField("Farm Name", farmName, { farmName = it }, "Blue Ocean Aquafarm")
        Spacer(Modifier.height(14.dp))
        SBTextField("Email Address", email, { email = it }, "you@farm.com",
            keyboardType = KeyboardType.Email)
        Spacer(Modifier.height(14.dp))
        SBTextField("Password", password, { password = it }, "Min. 8 characters", isPassword = true)
        Spacer(Modifier.height(20.dp))

        error?.let { ErrorBanner(it); Spacer(Modifier.height(10.dp)) }

        SBPrimaryButton("Create Farm Workspace", isLoading) {
            if (farmName.isBlank() || email.isBlank() || password.isBlank()) {
                error = "Please fill all fields."; return@SBPrimaryButton
            }
            scope.launch {
                isLoading = true; error = null
                try {
                    val res = RetrofitClient.api.register(
                        RegisterRequest(farmName, farmName, email, password))
                    if (res.isSuccessful && res.body()?.success == true) onSuccess()
                    else error = res.body()?.error ?: "Registration failed"
                } catch (e: Exception) { error = e.message }
                isLoading = false
            }
        }
    }
}

// ─── Forgot Password Screen ───────────────────────────────────────────────────

@Composable
fun ForgotPasswordScreen(onBack: () -> Unit, onSent: () -> Unit) {
    val scope = rememberCoroutineScope()
    var email    by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var error    by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(SBBg)
            .padding(24.dp)
    ) {
        TextButton(onClick = onBack) {
            Text("← Back to Sign In", fontWeight = FontWeight.SemiBold, color = SBPrimaryLight)
        }
        Spacer(Modifier.height(8.dp))
        Text("Forgot Password", fontSize = 26.sp, fontWeight = FontWeight.Bold, color = SBOnSurface)
        Text("Enter your email and we'll send a reset link.",
            fontSize = 13.sp, color = SBOnSurfaceVariant)
        Spacer(Modifier.height(28.dp))

        SBTextField("Email Address", email, { email = it }, "you@farm.com",
            keyboardType = KeyboardType.Email)
        Spacer(Modifier.height(10.dp))
        error?.let { ErrorBanner(it); Spacer(Modifier.height(10.dp)) }

        SBPrimaryButton("Send Reset Link", isLoading) {
            if (email.isBlank()) { error = "Enter your email address."; return@SBPrimaryButton }
            scope.launch {
                isLoading = true; error = null
                try {
                    val res = RetrofitClient.api.forgotPassword(mapOf("email" to email))
                    if (res.isSuccessful) onSent() else error = res.body()?.error ?: "Request failed"
                } catch (e: Exception) { error = e.message }
                isLoading = false
            }
        }
    }
}
