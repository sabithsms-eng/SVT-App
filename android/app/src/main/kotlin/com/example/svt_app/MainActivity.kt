package com.example.svt_app

import android.app.Activity
import android.content.Intent
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private companion object {
		const val channelName = "svt/contact_picker"
		const val contactPickerRequest = 1001
	}

	private var contactPickerResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				if (call.method != "pickContact") {
					result.notImplemented()
					return@setMethodCallHandler
				}

				if (contactPickerResult != null) {
					result.error("PICKER_BUSY", "A contact picker is already open", null)
					return@setMethodCallHandler
				}

				contactPickerResult = result
				val intent = Intent(
					Intent.ACTION_PICK,
					ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
				)
				startActivityForResult(intent, contactPickerRequest)
			}
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)
		if (requestCode != contactPickerRequest) return

		val result = contactPickerResult ?: return
		contactPickerResult = null
		if (resultCode != Activity.RESULT_OK || data?.data == null) {
			result.success(null)
			return
		}

		val uri = data.data!!
		val projection = arrayOf(
			ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
			ContactsContract.CommonDataKinds.Phone.NUMBER,
		)
		contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
			if (cursor.moveToFirst()) {
				result.success(
					mapOf(
						"name" to cursor.getString(0),
						"phone" to cursor.getString(1),
					),
				)
			} else {
				result.success(null)
			}
		} ?: result.success(null)
	}
}
